require 'json'
require 'digest'
require 'fileutils'
require 'optparse'

class WorldAssetBuilder
  class Error < StandardError; end
  KINDS = {'.glb'=>'model', '.gltf'=>'model', '.obj'=>'model', '.fbx'=>'model', '.blend'=>'model', '.vox'=>'model', '.wav'=>'audio', '.ogg'=>'audio', '.mp3'=>'audio', '.flac'=>'audio', '.png'=>'texture', '.svg'=>'texture', '.jpg'=>'texture', '.jpeg'=>'texture', '.tga'=>'texture', '.bin'=>'dependency', '.mtl'=>'dependency'}.freeze

  def initialize(root, config)
    @root, @config = File.realpath(root), config
    raise Error, 'World sources must use version 1 and pack/role/library dictionaries' unless config['version'] == 1 && %w[packs roles libraries].all? { |key| config[key].is_a?(Hash) }
  end

  def matches?(definition, pack, title)
    definition.fetch('packs', ['*']).any? { |pattern| File.fnmatch?(pattern, pack) } && definition.fetch('include', ['*']).any? { |pattern| File.fnmatch?(pattern.downcase, title.downcase) } && !definition.fetch('exclude', []).any? { |pattern| File.fnmatch?(pattern.downcase, title.downcase) }
  end

  def documents
    roles = @config['roles'].transform_values { [] }
    libraries = @config['libraries'].transform_values { [] }
    inventory, selected, packs, imports, seen = [], [], {}, [], {}
    Dir.glob(File.join(@root, 'import_assets/**/SOURCE.json')).sort.each do |source_path|
      next if source_path.include?('/license_review/')
      source = JSON.parse(File.read(source_path))
      id, dir = source.fetch('id'), File.dirname(source_path)
      files = Dir.glob(File.join(dir, '**/*')).select { |file| File.file?(file) && KINDS.key?(File.extname(file).downcase) }.sort
      definition = @config['packs'][id]
      included = definition ? files.select { |file| definition.fetch('include').any? { |glob| File.fnmatch?(glob, file.delete_prefix(dir+'/'), File::FNM_PATHNAME|File::FNM_EXTGLOB) } } : []
      primary_stems = included.map { |file| File.basename(file, File.extname(file)).downcase }
      unless included.empty?
        packs[id] = source.slice('id','title','author','source','license','license_url','attribution_required','attribution_text')
        imports << {'pack'=>id, 'include'=>definition['include'], 'kinds'=>included.map { |file| KINDS.fetch(File.extname(file).downcase) }.uniq.sort, 'tags'=>['world-construction']}
      end
      files.each do |file|
        raise Error, "Source file escapes its pack or is symlinked: #{file}" unless File.realpath(file)==file && File.realpath(file).start_with?(dir+'/')
        seen[file] = true
        relative = file.delete_prefix(dir+'/')
        title = File.basename(file, File.extname(file))
        asset_id = id+'/'+relative
        kind = KINDS.fetch(File.extname(file).downcase)
        assigned_roles, assigned_libraries = [], []
        status = if !definition
          'other_lane'
        elsif !included.include?(file)
          %w[texture dependency].include?(kind) ? 'support_resource' : primary_stems.include?(title.downcase) ? 'alternate_format' : 'unselected_representation'
        else
          @config['roles'].each { |role, query| assigned_roles << role if matches?(query, id, title) }
          @config['libraries'].each { |role, query| assigned_libraries << role if matches?(query, id, title) }
          assigned_roles.each { |role| roles[role] << asset_id }
          assigned_libraries.each { |role| libraries[role] << asset_id }
          selected << {'id'=>asset_id,'pack'=>id,'kind'=>kind,'roles'=>assigned_roles,'libraries'=>assigned_libraries}
          assigned_roles.empty? ? assigned_libraries.empty? ? 'unassigned_library' : 'assembly_library' : 'context_pool'
        end
        inventory << {'id'=>asset_id,'pack'=>id,'kind'=>kind,'source_file'=>file.delete_prefix(@root+'/'),'sha256'=>Digest::SHA256.file(file).hexdigest,'status'=>status,'roles'=>assigned_roles,'libraries'=>assigned_libraries}
      end
    end
    manifest_path = File.join(@root,'assets/source_manifest.json')
    legacy = File.file?(manifest_path) ? JSON.parse(File.read(manifest_path)).to_h { |entry| [entry.fetch('source'),entry] } : {}
    Dir.glob(File.join(@root,'import_assets/**/*')).sort.each do |file|
      next unless File.file?(file) && !seen[file] && KINDS.key?(File.extname(file).downcase)
      relative = file.delete_prefix(File.join(@root,'import_assets/'))
      raise Error, "Unregistered symlinked source: #{file}" unless File.realpath(file)==file
      status = file.include?('/license_review/') ? 'license_review' : legacy.key?(relative) ? 'legacy_runtime' : 'unregistered_source'
      inventory << {'id'=>'unregistered/'+relative,'pack'=>'','kind'=>KINDS.fetch(File.extname(file).downcase),'source_file'=>file.delete_prefix(@root+'/'),'sha256'=>Digest::SHA256.file(file).hexdigest,'status'=>status,'roles'=>[],'libraries'=>[],'runtime'=>legacy.fetch(relative,{}).fetch('runtime','')}
    end
    catalog = {'version'=>1, 'packs'=>packs, 'roles'=>roles, 'libraries'=>libraries, 'assets'=>selected}
    source_inventory = {'version'=>1, 'scope'=>'All recognized staged representations with SOURCE.json; environment/audio selection is owned here. Other gameplay/UI roles are coordinated separately.', 'summary'=>inventory.group_by { |entry| entry['status'] }.transform_values(&:size), 'assets'=>inventory}
    [catalog,source_inventory,{'version'=>1,'rules'=>imports}]
  end

  def build(check: false)
    paths = %w[assets/world_construction/catalog.json assets/world_construction/source_inventory.json config/generated_world_imports.json]
    documents.zip(paths).each do |document,path|
      target = File.join(@root,path)
      bytes = JSON.pretty_generate(document)+"\n"
      if check
        raise Error, "Stale world asset output: #{path}" unless File.file?(target) && File.read(target)==bytes
      elsif !File.file?(target) || File.read(target)!=bytes
        FileUtils.mkdir_p(File.dirname(target))
        temporary = target+".tmp-#{Process.pid}"
        File.write(temporary,bytes)
        File.rename(temporary,target)
      end
    end
    true
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {check:false,root:File.expand_path('..',__dir__)}
  OptionParser.new do |parser|
    parser.on('--check') { options[:check]=true }
    parser.on('--root PATH') { |path| options[:root]=File.expand_path(path) }
  end.parse!
  config = JSON.parse(File.read(File.join(options[:root],'config/world_asset_sources.json')))
  builder = WorldAssetBuilder.new(options[:root],config)
  builder.build(check:options[:check])
  catalog,inventory = builder.documents
  puts "PASS: world asset #{options[:check] ? 'freshness' : 'build'}; #{catalog['packs'].size} packs, #{catalog['assets'].size} canonical resources, #{catalog['roles'].size} semantic pools, #{inventory['assets'].size} source representations"
end
