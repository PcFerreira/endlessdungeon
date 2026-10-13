require 'digest'
require 'json'
require 'fileutils'
require 'open3'
require 'optparse'

class NetworkManifest
  class Error < StandardError; end
  ROOTS = %w[server/world_worker.gd].freeze
  PATH = 'config/network_manifest.json'.freeze

  def initialize(root, engine_version:, roots:ROOTS, generator_version:4)
    @root, @engine_version, @roots = File.realpath(root), engine_version, roots
    raise Error, "Unsupported generator edition: #{generator_version}" unless generator_version.is_a?(Integer) && [4,5,6,7].include?(generator_version)
    @generator_version = generator_version
  end

  def document
    inputs = {}
    pending = @roots.dup + Dir.glob(File.join(@root,'config/*.json')).map { |path| path.delete_prefix(@root + '/') }
    until pending.empty?
      relative = pending.shift
      next if relative == PATH || inputs.key?(relative)
      raise Error, "Invalid manifest path: #{relative}" if relative.start_with?('/') || relative.split('/').include?('..')
      path = File.join(@root,relative)
      raise Error, "Missing network authority input: #{relative}" unless File.file?(path)
      raise Error, "Network input escapes project: #{relative}" unless File.realpath(path).start_with?(@root + '/')
      inputs[relative] = Digest::SHA256.file(path).hexdigest
      next unless File.extname(relative) == '.gd'
      File.read(path).scan(/["']res:\/\/([^"']+\.(?:gd|json))["']/).each { |match| pending << match.first }
    end
    inputs = inputs.sort.to_h
    contract = {'protocol'=>1,'generator_version'=>@generator_version,'engine_version'=>@engine_version,'inputs'=>inputs}
    contract.merge('content_revision'=>Digest::SHA256.hexdigest(JSON.generate(contract)))
  end

  def fresh?
    path = File.join(@root,PATH)
    File.file?(path) && JSON.parse(File.read(path)) == document
  end

  def write
    path = File.join(@root,PATH)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path + '.tmp',JSON.pretty_generate(document) + "\n")
    File.rename(path + '.tmp',path)
  end
end

if $PROGRAM_NAME == __FILE__
  options = {root:File.expand_path('..',__dir__),check:false}
  OptionParser.new do |parser|
    parser.banner = 'Usage: ruby tools/build_network_manifest.rb [--check] [--root PATH] [--engine-version VERSION] [--generator-version 4|5|6]'
    parser.on('--check') { options[:check] = true }
    parser.on('--root PATH') { |value| options[:root] = value }
    parser.on('--engine-version VERSION') { |value| options[:engine_version] = value }
    parser.on('--generator-version VERSION', Integer) { |value| options[:generator_version] = value }
  end.parse!
  begin
    unless options[:engine_version]
      engine = File.join(options[:root],'.tools/Godot.app/Contents/MacOS/Godot')
      raise NetworkManifest::Error, 'Specify --engine-version when using another Godot installation' unless File.executable?(engine)
      version, status = Open3.capture2(engine,'--version')
      raise NetworkManifest::Error, 'Cannot read Godot engine version' unless status.success?
      options[:engine_version] = version.strip
    end
    manifest_path = File.join(options[:root],NetworkManifest::PATH)
    edition = options[:generator_version] || (File.file?(manifest_path) ? JSON.parse(File.read(manifest_path)).fetch('generator_version') : 4)
    builder = NetworkManifest.new(options[:root],engine_version:options[:engine_version],generator_version:edition)
    if options[:check]
      raise NetworkManifest::Error, 'Network content manifest is stale; rebuild before exporting or starting a new server release' unless builder.fresh?
    else
      builder.write
    end
    result = builder.document
    puts "PASS: network manifest #{options[:check] ? 'freshness' : 'build'}; #{result['inputs'].size} authority inputs, protocol #{result['protocol']}, generator #{result['generator_version']}, revision #{result['content_revision']}"
  rescue NetworkManifest::Error, JSON::ParserError, Errno::ENOENT, KeyError => error
    warn error.message
    exit 1
  end
end
