#!/usr/bin/env ruby
require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require_relative 'release_inputs'

root = File.expand_path('..', __dir__)
Dir.chdir(root)
abort 'Usage: ruby tools/build_windows.rb' unless ARGV.empty?
abort 'Render cache is stale; rebuild it before packaging' unless system('ruby', 'tools/check_render_cache.rb')
abort 'Network manifest is stale; refresh the coordinated release first' unless system('ruby', 'tools/build_network_manifest.rb', '--check')
manifest_hash = Digest::SHA256.file('config/network_manifest.json').hexdigest
sources = -> { ReleaseInputs.snapshot(root) }
source_hashes = sources.call
version, status = Open3.capture2('./godot.sh', '--version')
abort "Windows template requires Godot 4.7.2.stable; found #{version.strip}" unless status.success? && version.strip.start_with?('4.7.2.stable.')
template = '.tools/windows-templates/4.7.2.stable/windows_release_x86_64.exe'
provenance = File.join(File.dirname(template), 'SOURCE.json')
abort 'Run ruby tools/install_windows_templates.rb first' unless File.file?(template) && File.file?(provenance)
source = JSON.parse(File.read(provenance))
abort 'Windows template changed; reinstall official templates' unless source.fetch('templates').fetch(File.basename(template)) == Digest::SHA256.file(template).hexdigest
output = File.join(root, 'builds/windows-next')
final = File.join(root, 'builds/windows')
logs = File.join(root, 'builds/windows-logs')
abort 'Unfinished Windows staging directory exists; inspect builds/windows-next first' if Dir.exist?(output)
FileUtils.mkdir_p([output, logs])
executable = File.join(output, 'EndlessWorld.exe')
log, status = Open3.capture2e('./godot.sh', '--headless', '--export-release', 'Windows Desktop', executable)
File.write(File.join(logs, 'export.log'), log)
abort 'Windows export failed; inspect builds/windows-logs/export.log' unless status.success? && !log.match?(/SCRIPT ERROR:|^ERROR:/)
File.open(executable, 'rb') do |binary|
  abort 'Export is not a Windows executable' unless binary.read(2) == 'MZ'
  binary.seek(0x3c)
  binary.seek(binary.read(4).unpack1('V'))
  abort 'Export is not Windows x86_64 PE' unless binary.read(6) == "PE\x00\x00\x64\x86".b
end
isolated = File.join(root, '.tools/windows-pack-check')
FileUtils.mkdir_p(isolated)
check, status = Open3.capture2e('./godot.sh', '--headless', '--path', isolated, '--main-pack', executable, '--script', File.join(root, 'tools/check_web_pack.gd'), '--', '--manifest-sha256', manifest_hash)
File.write(File.join(logs, 'pack-check.log'), check)
abort 'Windows embedded pack failed; inspect builds/windows-logs/pack-check.log' unless status.success? && check.include?('PASS: Web export pack') && !check.match?(/SCRIPT ERROR:|^ERROR:/)
launch, status = Open3.capture2e('./godot.sh', '--headless', '--path', isolated, '--main-pack', executable, '--script', File.join(root, 'tools/check_windows_launch.gd'), '--quit-after', '600')
File.write(File.join(logs, 'launch-check.log'), launch)
abort 'Packed game startup failed; inspect builds/windows-logs/launch-check.log' unless status.success? && launch.include?('PASS: isolated Windows embedded pack') && !launch.match?(/SCRIPT ERROR:|^ERROR:|^WARNING:/)
release, status = Open3.capture2e('ruby', File.join(root, 'tools/check_release_runtime.rb'), executable)
File.write(File.join(logs, 'release-runtime-check.log'), release)
abort 'Release-mode chunk/icon check failed; inspect builds/windows-logs/release-runtime-check.log' unless status.success?
notices = Dir.glob('assets/**/*').select { |path| File.file?(path) && File.basename(path).match?(/(?:LICENSE|License|license|OFL|SOURCE|CREDITS|attribution|Attribution)/) && ['', '.txt', '.md', '.json', '.html'].include?(File.extname(path)) }
notices << 'CREDITS.md'
notices.each do |path|
  destination = File.join(output, path)
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.cp(path, destination)
end
File.write(File.join(output, 'README.txt'), "Endless World: The Wandering Lands\nWindows 64-bit release\n\nDouble-click EndlessWorld.exe to play. Game data is embedded in the executable.\nKeep the included credits and license notices when sharing this release.\nNative play includes offline journeys; shared worlds require a running compatible server.\n\nThis release was cross-exported on macOS. Embedded resources were checked independently\nof the source checkout; execution on Windows remains to be tested.\n\nGodot Engine (MIT): https://godotengine.org/license/\nEngine component notices: https://github.com/godotengine/godot/blob/4.7.2-stable/COPYRIGHT.txt\n")
File.write(File.join(output, 'EndlessWorld-ThreadedRendering.bat'), "@echo off\r\nstart \"\" \"%~dp0EndlessWorld.exe\" --render-thread separate\r\n")
File.open(File.join(output, 'README.txt'), 'a') { |file| file.write("\nThis update prepares nearby offline chunks on a background worker, reuses\nnavigation and rendering meshes, and includes baked creature/vegetation scenes.\nEndlessWorld-ThreadedRendering.bat additionally tries Godot's experimental\nseparate rendering thread. Launch the EXE normally for the standard render mode.\n") }
abort 'Source changed during Windows export; repeat after coordination' unless sources.call == source_hashes && Digest::SHA256.file('config/network_manifest.json').hexdigest == manifest_hash && system('ruby', 'tools/build_network_manifest.rb', '--check')
abort 'Render cache changed during Windows export; repeat after coordination' unless system('ruby', 'tools/check_render_cache.rb')
report = {godot: version.strip, mode: 'release', platform: 'Windows', architecture: 'x86_64', embedded_pck: true, content_revision: JSON.parse(File.read('config/network_manifest.json')).fetch('content_revision'), game_source_revision: Digest::SHA256.hexdigest(JSON.generate(source_hashes)), built_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'), executable_bytes: File.size(executable), executable_sha256: Digest::SHA256.file(executable).hexdigest, notice_files: notices.size, host_pack_launch_tested: true, release_runtime_streaming_icons_tested: true, release_runtime_platform: 'macOS', windows_execution_tested: false}
File.write(File.join(output, 'build-report.json'), JSON.pretty_generate(report) + "\n")
abort 'An existing Windows release needs archiving before replacement' if Dir.exist?(final)
File.rename(output, final)
archive = File.join(root, 'builds', 'EndlessWorld-windows-x86_64.zip')
abort 'Existing Windows ZIP needs archiving before replacement' if File.exist?(archive)
abort 'Release ZIP failed' unless system('zip', '-qr', archive, 'windows', chdir: File.dirname(final))
abort 'Release ZIP integrity failed' unless system('unzip', '-tq', archive)
puts "Windows release: #{final}/EndlessWorld.exe (#{report[:executable_bytes]} bytes)"
puts "Shareable package: #{archive}"
