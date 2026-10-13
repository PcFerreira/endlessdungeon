#!/usr/bin/env ruby
require 'cgi'
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'zlib'
require_relative 'release_inputs'

root = File.expand_path('..', __dir__)
Dir.chdir(root)
debug = ARGV.delete('--debug')
abort 'Usage: ruby tools/build_web.rb [--debug]' unless ARGV.empty?
abort 'Render cache is stale; rebuild it before packaging' if File.file?('assets/render_cache/catalog.json') && !system('ruby', 'tools/check_render_cache.rb')
abort 'Network manifest is stale; refresh the coordinated release first' unless system('ruby', 'tools/build_network_manifest.rb', '--check')
manifest_hash = Digest::SHA256.file('config/network_manifest.json').hexdigest
manifest = JSON.parse(File.read('config/network_manifest.json'))
game_sources = -> { ReleaseInputs.snapshot(root) }
source_hashes = game_sources.call
launcher_hashes = ['tools/web_shell.html','tools/web_lan_policy.mjs'].to_h { |path| [path,Digest::SHA256.file(path).hexdigest] }
engine = File.join(root, 'godot.sh')
version, status = Open3.capture2(engine, '--version')
abort "Web templates require Godot 4.7.2.stable; found #{version.strip}" unless status.success? && version.strip.start_with?('4.7.2.stable.')
templates = '.tools/web-templates/4.7.2.stable'
abort 'Run ruby tools/install_web_templates.rb first' unless ['debug', 'release'].all? { |mode| File.file?("#{templates}/web_nothreads_#{mode}.zip") }
source = JSON.parse(File.read("#{templates}/SOURCE.json"))
['debug', 'release'].each do |mode|
  name = "web_nothreads_#{mode}.zip"
  abort "Template changed: #{name}; reinstall official templates" unless source.fetch('templates').fetch(name) == Digest::SHA256.file("#{templates}/#{name}").hexdigest
end
output = File.join(root, 'builds/web-next')
final = File.join(root, 'builds/web')
logs = File.join(root, 'builds/web-logs')
FileUtils.rm_rf(output)
FileUtils.mkdir_p([output, logs])
FileUtils.cp('tools/web_lan_policy.mjs',File.join(output,'lan-http-policy.js'))
log_path = File.join(logs, 'export.log')
command = [engine, '--headless', debug ? '--export-debug' : '--export-release', 'Web', File.join(output, 'index.html')]
File.open(log_path, 'w') do |log|
  Open3.popen2e(*command) do |input, stream, process|
    input.close
    stream.each_line { |line| log.write(line) }
    abort "Export failed; inspect #{log_path}" unless process.value.success?
  end
end
abort "Export reported errors; inspect #{log_path}" if File.read(log_path).match?(/(?:SCRIPT ERROR:|^ERROR:)/)
isolated = File.join(root, '.tools/web-pack-check')
FileUtils.mkdir_p(isolated)
check, status = Open3.capture2e(engine, '--headless', '--path', isolated, '--main-pack', File.join(output, 'index.pck'), '--script', File.join(root, 'tools/check_web_pack.gd'), '--', '--manifest-sha256', manifest_hash)
File.write(File.join(logs, 'pack-check.log'), check)
abort "Export pack check failed; inspect #{logs}/pack-check.log" unless status.success? && check.include?('PASS: Web export pack') && !check.match?(/(?:SCRIPT ERROR:|^ERROR:)/)
notices = Dir.glob('assets/**/*').select { |path| File.file?(path) && File.basename(path).match?(/(?:LICENSE|License|license|OFL|SOURCE|CREDITS|attribution|Attribution)/) && ['', '.txt', '.md', '.json', '.html'].include?(File.extname(path)) }
notices << 'CREDITS.md'
notices.each do |path|
  destination = File.join(output, path)
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.cp(path, destination)
end
links = notices.sort.map { |path| "<li><a href=\"#{CGI.escapeHTML(path)}\">#{CGI.escapeHTML(path)}</a></li>" }.join("\n")
File.write(File.join(output, 'credits.html'), "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\"><title>Endless World credits</title><h1>Endless World credits and licenses</h1><p><a href=\"CREDITS.md\">Game credits</a></p><p>Built with <a href=\"https://godotengine.org/license/\">Godot Engine (MIT)</a>. <a href=\"https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt\">Engine component notices</a>.</p><ul>#{links}</ul></html>\n")
files = (Dir.glob(File.join(output, 'index.*')) + [File.join(output,'lan-http-policy.js')]).reject { |path| path.end_with?('.gz') }
sizes = files.to_h do |path|
  Zlib::GzipWriter.open(path + '.gz', Zlib::BEST_COMPRESSION) { |zip| File.open(path, 'rb') { |source| IO.copy_stream(source, zip) } }
  [File.basename(path), {bytes: File.size(path), gzip_bytes: File.size(path + '.gz'), sha256: Digest::SHA256.file(path).hexdigest}]
end
abort 'Network manifest changed during export; build again after publication' unless Digest::SHA256.file('config/network_manifest.json').hexdigest == manifest_hash && system('ruby', 'tools/build_network_manifest.rb', '--check')
abort 'Game source changed during export; repeat after source is stable' unless game_sources.call == source_hashes
abort 'Render cache changed during export; repeat after source is stable' if File.file?('assets/render_cache/catalog.json') && !system('ruby', 'tools/check_render_cache.rb')
abort 'Launcher changed during export; repeat after source is stable' unless launcher_hashes.all? { |path,hash| Digest::SHA256.file(path).hexdigest == hash }
report = {godot: version.strip, mode: debug ? 'debug' : 'release', thread_support: false, content_revision: manifest.fetch('content_revision'), manifest_sha256: manifest_hash, game_source_revision: Digest::SHA256.hexdigest(JSON.generate(source_hashes)), built_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'), files: sizes, bytes: sizes.values.sum { |entry| entry[:bytes] }, gzip_bytes: sizes.values.sum { |entry| entry[:gzip_bytes] }, notice_files: notices.length}
report[:launcher_revision] = Digest::SHA256.hexdigest(JSON.generate(launcher_hashes))
File.write(File.join(output, 'build-report.json'), JSON.pretty_generate(report) + "\n")
FileUtils.rm_rf(final)
File.rename(output, final)
puts "Web export: #{report[:bytes]} bytes raw; #{report[:gzip_bytes]} bytes gzip; #{notices.length} public notice files"
puts "Serve with: .tools/node/bin/node tools/serve_web.mjs"
