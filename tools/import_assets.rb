require 'json'
require 'yaml'
require 'fileutils'
require 'digest'
require 'uri'
require 'tmpdir'
require 'optparse'

class AssetImporter
  class Error < StandardError; end
  KINDS = {'.gltf' => 'model', '.glb' => 'model', '.obj' => 'model', '.fbx' => 'model', '.png' => 'texture', '.svg' => 'texture', '.jpg' => 'texture', '.jpeg' => 'texture', '.ogg' => 'audio', '.wav' => 'audio', '.mp3' => 'audio'}.freeze
  NOTICE = /(?:license|licence|copyright|attribution|credits|readme)/i

  def initialize(root, config)
    @root, @config = File.realpath(root), config
    raise Error, 'Importer config must be an object with version 1' unless config.is_a?(Hash) && config.fetch('version', 1) == 1
    @config = @config.dup
    @config['rules'] = @config.fetch('rules', []).dup
    @config.fetch('rule_files', []).each do |relative|
      path = checked_file(File.expand_path(relative, @root), File.join(@root, 'config'))
      fragment = json(path)
      raise Error, "Invalid rule fragment: #{relative}" unless fragment['version'] == 1 && fragment['rules'].is_a?(Array)
      @config['rules'].concat(fragment['rules'])
    end
    %w[rules lore_sources].each { |key| raise Error, "#{key} must be an array" unless config.fetch(key, []).is_a?(Array) }
    @output = File.join(@root, 'assets/imported')
  end

  def checked_file(path, boundary)
    raise Error, "Missing source: #{path}" unless File.file?(path)
    resolved = File.realpath(path)
    raise Error, "Source escapes its content root: #{path}" unless resolved.start_with?(File.realpath(boundary) + '/')
    raise Error, "Symlinked asset sources are not supported: #{path}" unless resolved == File.expand_path(path)
    resolved
  end

  def json(path)
    JSON.parse(File.read(path))
  rescue JSON::ParserError => e
    raise Error, "Invalid JSON in #{path}: #{e.message}"
  end

  def tags(values)
    raise Error, 'Tags/categories must be an array of strings' unless values.is_a?(Array) && values.all? { |v| v.is_a?(String) }
    values.map { |value| value.to_s.downcase.gsub(/[^a-z0-9]+/, '-').sub(/^-/, '').sub(/-$/, '') }.reject(&:empty?).uniq.sort
  end

  def scan
    @packs = {}
    assets = []
    staging = File.join(@root, 'import_assets')
    Dir.glob(File.join(staging, '**/SOURCE.json')).sort.each do |path|
      next if path.include?('/license_review/')
      checked_file(path, staging)
      source = json(path)
      id = source['id']
      raise Error, "Invalid pack ID in #{path}" unless id.is_a?(String) && id.match?(/\A[a-zA-Z0-9_-]+\z/)
      raise Error, "Duplicate pack ID: #{id}" if @packs.key?(id)
      %w[title author source license license_url].each { |key| raise Error, "Missing #{key} in #{path}" unless source[key].is_a?(String) && !source[key].empty? }
      directory = File.dirname(path)
      @packs[id] = {'source' => source, 'directory' => directory}
      Dir.glob(File.join(directory, '**/*')).sort.each do |file|
        next unless File.file?(file) && KINDS.key?(File.extname(file).downcase)
        relative = file.delete_prefix(directory + '/')
        kind = KINDS.fetch(File.extname(file).downcase)
        name_tags = File.basename(file, File.extname(file)).split(/[_\- ]+/)
        assets << {'id' => "#{id}/#{relative}", 'pack' => id, 'source_file' => file.delete_prefix(@root + '/'), 'relative' => relative, 'kind' => kind, 'title' => File.basename(file, File.extname(file)), 'tags' => tags(source.fetch('categories', []) + name_tags), 'aliases' => []}
      end
    end
    assets.concat(lore_entries)
    ids = assets.map { |a| a.fetch('id') }
    raise Error, 'Duplicate content ID' unless ids.uniq.size == ids.size
    {'version' => 1, 'packs' => @packs.transform_values { |p| p['source'].slice('id', 'title', 'author', 'source', 'license', 'license_url', 'attribution_required', 'attribution_text') }, 'assets' => assets.sort_by { |a| a['id'] }}
  end

  def lore_entries
    entries = []
    seen = []
    boundary = File.join(@root, 'lore')
    @config.fetch('lore_sources', []).each do |rule|
      Dir.glob(File.join(@root, rule.fetch('glob'))).sort.each do |path|
        next if seen.include?(path)
        checked_file(path, boundary)
        seen << path
        body = File.read(path, encoding: 'UTF-8')
        records = case rule.fetch('format')
        when 'entries'
          document = json(path)
          document.is_a?(Array) ? document : [document]
        when 'markdown'
          markdown_entries(body)
        else
          raise Error, "Unknown lore format: #{rule['format']}"
        end
        records.each do |entry|
          raise Error, "Lore entry must be an object: #{path}" unless entry.is_a?(Hash)
          entry = entry.dup
          %w[id kind].each { |key| raise Error, "Missing lore #{key} in #{path}" unless entry[key].is_a?(String) && !entry[key].empty? }
          raise Error, "Invalid lore ID in #{path}" unless entry['id'].match?(/\A[a-zA-Z0-9_\/.\-]+\z/) && !entry['id'].split('/').include?('..')
          if entry['file']
            file = checked_file(File.expand_path(entry.delete('file'), File.dirname(path)), boundary)
            entry['text'] = File.read(file, encoding: 'UTF-8')
            entry['text_source'] = file.delete_prefix(@root + '/')
          end
          raise Error, "Empty lore text in #{path}: #{entry['id']}" unless entry['text'].is_a?(String) && !entry['text'].strip.empty?
          content_type = entry['kind']
          if content_type == 'book'
            raise Error, "Missing book title in #{path}" unless entry['title'].is_a?(String) && !entry['title'].empty?
            entry['author'] ||= 'Anonymous'
          elsif content_type == 'dialogue'
            %w[speaker event].each { |key| raise Error, "Missing dialogue #{key} in #{path}" unless entry[key].is_a?(String) && !entry[key].empty? }
            entry['condition'] ||= 'Any'
            raise Error, "Invalid dialogue condition in #{path}" unless entry['condition'].is_a?(String)
          end
          if entry['license']
            %w[license author source license_url license_file].each { |key| raise Error, "Licensed lore requires #{key}: #{path}" unless entry[key].is_a?(String) && !entry[key].empty? }
            notice = checked_file(File.expand_path(entry['license_file'], File.dirname(path)), boundary)
            entry['license_source'] = notice.delete_prefix(@root + '/')
          end
          entry.merge!('kind' => 'text', 'content_type' => content_type, 'source_file' => path.delete_prefix(@root + '/'), 'pack' => 'lore', 'tags' => tags(entry.fetch('tags', []) + [content_type]), 'aliases' => entry.fetch('aliases', []))
          entries << entry
        end
      end
    end
    entries
  rescue Psych::Exception => e
    raise Error, "Invalid lore front matter: #{e.message}"
  end

  def markdown_entries(body)
    if body.start_with?("---\n")
      match = body.match(/\A---\n(.*?)\n---\n(.*)\z/m)
      raise Error, 'Unclosed lore front matter' unless match
      metadata = YAML.safe_load(match[1], aliases: false)
      raise Error, 'Lore front matter must be an object' unless metadata.is_a?(Hash)
      return [metadata.merge('text' => match[2])]
    end
    entries = []
    body.split(/^## /).drop(1).each do |section|
      id = section[/Book ID: `([^`]+)`/, 1]
      next unless id
      paragraphs = section.lines.select { |line| line.start_with?('>') }.map { |line| line.sub(/^> ?/, '').rstrip }
      entries << {'id' => id, 'kind' => 'book', 'title' => section.lines.first.strip, 'author' => section[/Author: (.*?)\. Placement:/, 1], 'text' => paragraphs.join("\n")}
    end
    headers = []
    body.each_line do |line|
      unless line.start_with?('|')
        headers = []
        next
      end
      cells = line.strip.split('|', -1)[1...-1].map { |c| c.strip }
      if cells.map(&:downcase).include?('speaker') && cells.map(&:downcase).include?('event')
        headers = cells.map { |c| c.downcase.sub('line id', 'id').sub('eligibility', 'condition').sub('conditions', 'condition') }
        next
      end
      next unless headers.include?('text') && headers.include?('id') && cells.size == headers.size && cells.first.start_with?('`')
      entry = headers.zip(cells).to_h
      %w[id speaker event].each { |key| entry[key] = entry[key].delete('`') }
      entry['condition'] ||= entry['id'].include?('_memory_') ? 'Once per speaker' : 'Any'
      entries << entry.merge('kind' => 'dialogue')
    end
    entries
  end

  def matches?(rule, asset)
    return false if rule['enabled'] == false || !File.fnmatch?(rule.fetch('pack', '*'), asset['pack'])
    return false if rule['kinds'] && !rule['kinds'].include?(asset['kind'])
    return false unless rule.fetch('match_tags', []).all? { |tag| asset['tags'].include?(tag) }
    flags = File::FNM_PATHNAME | File::FNM_EXTGLOB
    included = rule.fetch('include', ['**/*']).any? { |glob| File.fnmatch?(glob, asset['relative'], flags) }
    included && !rule.fetch('exclude', []).any? { |glob| File.fnmatch?(glob, asset['relative'], flags) }
  end

  def dependency(path, uri, boundary)
    return nil if uri.start_with?('data:')
    raise Error, "External or absolute dependency in #{path}: #{uri}" if uri.match?(/\A(?:[a-zA-Z][a-zA-Z0-9+.-]*:|\/|\\)/) || uri.include?('\\')
    decoded = URI::DEFAULT_PARSER.unescape(uri)
    checked_file(File.expand_path(decoded, File.dirname(path)), boundary)
  end

  def gltf_document(path)
    return json(path) if File.extname(path).downcase == '.gltf'
    bytes = File.binread(path)
    magic, version, length = bytes.unpack('a4V2')
    raise Error, "Invalid GLB header: #{path}" unless magic == 'glTF' && version == 2 && length == bytes.bytesize
    size, type = bytes.byteslice(12, 8).to_s.unpack('Va4')
    raise Error, "Invalid GLB JSON chunk: #{path}" unless type == 'JSON' && size && size <= length - 20
    JSON.parse(bytes.byteslice(20, size))
  rescue JSON::ParserError => e
    raise Error, "Invalid model JSON: #{path}: #{e.message}"
  end

  def dependencies(path, boundary)
    case File.extname(path).downcase
    when '.gltf', '.glb'
      document = gltf_document(path)
      raise Error, "Unsupported glTF version: #{path}" unless document.dig('asset', 'version') == '2.0'
      (document.fetch('buffers', []) + document.fetch('images', [])).map { |item| dependency(path, item['uri'], boundary) if item['uri'] }.compact
    when '.obj'
      File.read(path).scan(/^mtllib\s+(.+)$/).flatten.map { |uri| dependency(path, uri.strip, boundary) }
    when '.mtl'
      File.read(path).scan(/^(?:map_\w+|bump|disp|decal)\s+(.+)$/i).flatten.map do |uri|
        raise Error, "MTL map options require a normalized texture reference: #{path}" if uri.start_with?('-')
        dependency(path, uri.strip, boundary)
      end
    when '.svg'
      File.read(path).scan(/(?:href|xlink:href)=["']([^"']+)["']/).flatten.reject { |uri| uri.start_with?('#') }.map { |uri| dependency(path, uri, boundary) }.compact
    when '.fbx'
      raise Error, "Select a glTF/GLB/OBJ export instead of FBX: #{path}; FBX dependencies are not portable"
    else
      []
    end
  end

  def build(check: false)
    lock_path = File.join(Dir.tmpdir, 'endless-assets-' + Digest::SHA256.hexdigest(@root) + '.lock')
    File.open(lock_path, 'w') do |lock|
      lock.flock(File::LOCK_EX)
      build_locked(check: check)
    end
  end

  def build_locked(check: false)
    scan_result = scan
    unknown = @config.fetch('overrides', {}).keys - scan_result['assets'].map { |entry| entry['id'] }
    raise Error, "Overrides refer to unknown IDs: #{unknown.join(', ')}" unless unknown.empty?
    rules = @config.fetch('rules', [])
    rules.each do |rule|
      next if rule['enabled'] == false
      raise Error, "Pack selector matched no discovered packs: #{rule['pack']}" unless @packs.keys.any? { |id| File.fnmatch?(rule.fetch('pack', '*'), id) }
    end
    files = {}
    records = []
    selected_packs = []
    add_file = lambda do |path, boundary, prefix|
      path = checked_file(path, boundary)
      target = prefix + '/' + path.delete_prefix(File.realpath(boundary) + '/')
      return if files.key?(target)
      files[target] = {'source' => path.delete_prefix(@root + '/'), 'sha256' => Digest::SHA256.file(path).hexdigest}
      dependencies(path, boundary).each { |dep| add_file.call(dep, boundary, prefix) }
    end
    scan_result['assets'].each do |original|
      matching = original['kind'] == 'text' ? [] : rules.select { |rule| matches?(rule, original) }
      next if original['kind'] != 'text' && matching.empty?
      entry = original.dup
      overrides = @config.fetch('overrides', {}).fetch(entry['id'], {})
      raise Error, "Override cannot replace asset identity or source: #{entry['id']}" unless (overrides.keys - %w[aliases tags scale rotation_degrees offset]).empty?
      entry.merge!(overrides)
      entry['tags'] = tags(original['tags'] + matching.flat_map { |rule| rule.fetch('tags', []) } + overrides.fetch('tags', []))
      if entry['scale']
        raise Error, "Invalid model scale: #{entry['id']}" unless entry['scale'].is_a?(Numeric) && entry['scale'].finite? && entry['scale'] > 0
      end
      %w[rotation_degrees offset].each do |key|
        next unless entry[key]
        raise Error, "Invalid #{key}: #{entry['id']}" unless entry[key].is_a?(Array) && entry[key].size == 3 && entry[key].all? { |v| v.is_a?(Numeric) && v.finite? }
      end
      raise Error, "Invalid aliases: #{entry['id']}" unless entry['aliases'].is_a?(Array) && entry['aliases'].all? { |a| a.is_a?(String) && !a.empty? }
      if entry['kind'] == 'text'
        add_file.call(File.join(@root, entry['source_file']), File.join(@root, 'lore'), 'sources/lore')
        add_file.call(File.join(@root, entry['text_source']), File.join(@root, 'lore'), 'sources/lore') if entry['text_source']
        add_file.call(File.join(@root, entry['license_source']), File.join(@root, 'lore'), 'sources/lore') if entry['license_source']
      else
        pack = @packs.fetch(entry['pack'])
        add_file.call(File.join(@root, entry['source_file']), pack['directory'], "packs/#{entry['pack']}")
        entry['path'] = "res://assets/imported/packs/#{entry['pack']}/#{entry.delete('relative')}"
        entry.merge!(pack['source'].slice('author', 'source', 'license', 'license_url', 'attribution_required', 'attribution_text'))
        selected_packs << entry['pack']
      end
      records << entry
    end
    keys = records.flat_map { |entry| [entry['id']] + entry['aliases'] }
    raise Error, 'Duplicate asset ID or alias' unless keys.uniq.size == keys.size
    selected_packs.uniq.each do |id|
      directory = @packs[id]['directory']
      notices = Dir.glob(File.join(directory, '**/*')).select { |p| File.file?(p) && File.basename(p).match?(NOTICE) && ['', '.txt', '.md', '.html'].include?(File.extname(p).downcase) }
      raise Error, "No license document for pack #{id}" unless notices.any? { |p| File.basename(p).match?(/licen[sc]e/i) }
      notices.concat(Dir.glob(File.join(directory, 'CONVERSIONS.json')))
      (notices + [File.join(directory, 'SOURCE.json')]).each { |path| add_file.call(path, directory, "packs/#{id}") }
    end
    catalog = {'version' => 1, 'packs' => scan_result['packs'].slice(*selected_packs.uniq.sort), 'assets' => records.sort_by { |a| a['id'] }, 'files' => files.sort.to_h}
    destination = File.join(@output, 'catalog.json')
    current = File.file?(destination) ? json(destination) : nil
    unchanged = current == catalog && files.all? { |relative, file| path = File.join(@output, relative); File.file?(path) && Digest::SHA256.file(path).hexdigest == file['sha256'] }
    raise Error, 'Generated catalog is out of date; run ruby tools/import_assets.rb --build' if check && !unchanged
    return catalog if check || unchanged
    raise Error, "Refusing to replace unmanaged output: #{@output}" if File.exist?(@output) && !File.file?(File.join(@output, '.asset-importer.json'))
    art_files = files.select { |relative, _| relative.start_with?('packs/') }
    reuse_art = current && current.fetch('files', {}).select { |relative, _| relative.start_with?('packs/') } == art_files && art_files.all? { |relative, file| path = File.join(@output, relative); File.file?(path) && Digest::SHA256.file(path).hexdigest == file['sha256'] }
    FileUtils.mkdir_p(File.dirname(@output))
    Dir.mktmpdir('.asset-build-', File.dirname(@output)) do |workspace|
      File.write(File.join(workspace, '.gdignore'), '')
      stage = File.join(workspace, 'content')
      FileUtils.mkdir_p(stage)
      File.write(File.join(stage, '.gdignore'), '')
      FileUtils.cp_r(File.join(@output, 'packs'), File.join(stage, 'packs'), preserve: true) if reuse_art && File.directory?(File.join(@output, 'packs'))
      files.each do |relative, file|
        next if reuse_art && relative.start_with?('packs/')
        target = File.join(stage, relative)
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.cp(File.join(@root, file['source']), target)
        raise Error, "Source changed while building: #{file['source']}" unless Digest::SHA256.file(target).hexdigest == file['sha256']
        if current && current.fetch('files', {}).dig(relative, 'sha256') == file['sha256']
          suffixes = %w[.gltf .glb .obj].include?(File.extname(relative).downcase) ? ['.uid'] : %w[.import .uid]
          suffixes.each { |suffix| FileUtils.cp(File.join(@output, relative + suffix), target + suffix) if File.file?(File.join(@output, relative + suffix)) }
        end
      end
      File.write(File.join(stage, 'catalog.json'), JSON.pretty_generate(catalog) + "\n")
      credits = catalog['packs'].values.map { |p| p['attribution_text'] || "#{p['title']} by #{p['author']}. Source: #{p['source']}. License: #{p['license']} (#{p['license_url']})." }
      credits += records.select { |e| e['kind'] == 'text' && e['license'] }.map { |e| "#{e.fetch('title', e['id'])} by #{e.fetch('author', 'Unspecified')}. License: #{e['license']}. #{e.fetch('attribution_text', '')}" }
      File.write(File.join(stage, 'CREDITS.md'), "# Imported content credits\n\nCopy required credits for assets used in the shipped game. Full license notices are retained in packs/. Project lore without an explicit external license retains the project's existing authorship terms.\n\n" + credits.uniq.map { |c| "- #{c}" }.join("\n\n") + "\n")
      File.write(File.join(stage, '.asset-importer.json'), JSON.generate({'version' => 1}))
      FileUtils.rm(File.join(stage, '.gdignore'))
      backup = stage + '-previous'
      begin
        File.rename(@output, backup) if File.exist?(@output)
        File.rename(stage, @output)
      rescue
        File.rename(backup, @output) if File.exist?(backup) && !File.exist?(@output)
        raise
      ensure
        FileUtils.rm_rf(backup) if File.exist?(@output)
      end
    end
    catalog
  end
end

if $PROGRAM_NAME == __FILE__
  options = {mode: 'build', root: File.expand_path('..', __dir__)}
  parser = OptionParser.new do |o|
    o.banner = 'Usage: ruby tools/import_assets.rb [--scan | --build | --check] [--root PATH] [--config PATH]'
    %w[scan build check].each { |mode| o.on("--#{mode}") { options[:mode] = mode } }
    o.on('--root PATH') { |path| options[:root] = File.expand_path(path) }
    o.on('--config PATH') { |path| options[:config] = File.expand_path(path) }
  end
  begin
    parser.parse!
    config_path = options[:config] || File.join(options[:root], 'config/asset_imports.json')
    importer = AssetImporter.new(options[:root], JSON.parse(File.read(config_path)))
    if options[:mode] == 'scan'
      puts JSON.pretty_generate(importer.scan)
    else
      catalog = importer.build(check: options[:mode] == 'check')
      puts "PASS: #{catalog['packs'].size} packs, #{catalog['assets'].size} catalog entries, #{catalog['files'].size} files; #{options[:mode]}"
    end
  rescue AssetImporter::Error, JSON::ParserError, KeyError, Errno::ENOENT, OptionParser::ParseError => e
    warn "Asset import failed: #{e.message}"
    exit 1
  end
end
