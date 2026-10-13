require 'json'
require 'fileutils'
require 'optparse'
require_relative '../import_assets'

class EditorAssetImport
  def initialize(root)
    @root = File.realpath(root)
    @config_path = File.join(@root, 'config/asset_imports.json')
    @fragment_path = File.join(@root, 'config/editor_asset_imports.json')
  end

  def publish(path, document)
    temporary = "#{path}.editor-#{Process.pid}"
    File.write(temporary, JSON.pretty_generate(document) + "\n")
    JSON.parse(File.read(temporary))
    File.rename(temporary, path)
  ensure
    FileUtils.rm_f(temporary) if temporary
  end

  def stage(id)
    File.open(File.join(@root, 'config/.content-editor-import.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
      lock.flock(File::LOCK_EX)
      config = JSON.parse(File.read(@config_path))
      importer = AssetImporter.new(@root, config)
      asset = importer.scan['assets'].find { |entry| entry['id'] == id }
      raise AssetImporter::Error, 'Asset is not in a source pack with SOURCE.json' unless asset
      raise AssetImporter::Error, 'Stage a glTF/GLB/OBJ model, texture or audio file' unless AssetImporter::KINDS.key?(File.extname(asset['source_file']).downcase) && File.extname(asset['source_file']).downcase != '.fbx'
      importer.checked_file(File.join(@root, asset['source_file']), File.join(@root, 'import_assets'))
      fragment = File.exist?(@fragment_path) ? JSON.parse(File.read(@fragment_path)) : {'version' => 1, 'rules' => []}
      raise AssetImporter::Error, 'Invalid editor import rules' unless fragment['version'] == 1 && fragment['rules'].is_a?(Array)
      literal = asset['relative'].gsub(/([\\*?\[\]{}])/) { |char| "\\#{char}" }
      rule = {'pack' => asset['pack'], 'kinds' => [asset['kind']], 'include' => [literal], 'tags' => ['editor-adopted']}
      fragment['rules'] << rule unless fragment['rules'].include?(rule)
      publish(@fragment_path, fragment)
      config['rule_files'] ||= []
      config['rule_files'] << 'config/editor_asset_imports.json' unless config['rule_files'].include?('config/editor_asset_imports.json')
      publish(@config_path, config)
      asset
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {root: File.expand_path('../..', __dir__)}
  OptionParser.new do |parser|
    parser.on('--asset ID') { |id| options[:asset] = id }
    parser.on('--root PATH') { |path| options[:root] = path }
    parser.on('--queue-only') { options[:queue_only] = true }
  end.parse!
  begin
    raise AssetImporter::Error, '--asset is required' unless options[:asset]
    asset = EditorAssetImport.new(options[:root]).stage(options[:asset])
    puts "Queued #{asset['id']} with its source provenance"
    unless options[:queue_only]
      %w[import_assets.rb build_world_assets.rb build_content_bundles.rb].each do |script|
        arguments = ['ruby', File.join(options[:root], 'tools', script), '--root', options[:root]]
        raise AssetImporter::Error, "Failed #{script}" unless system(*arguments)
      end
    end
  rescue AssetImporter::Error, JSON::ParserError, KeyError, Errno::ENOENT => error
    warn "Asset adoption failed: #{error.message}"
    exit 1
  end
end
