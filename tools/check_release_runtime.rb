#!/usr/bin/env ruby
require 'fileutils'
require 'open3'
require 'tmpdir'
require 'digest'
require 'json'

root = File.expand_path('..', __dir__)
executable = File.expand_path(ARGV.fetch(0))
engine = File.join(root, '.tools/release-runtime/godot_macos_release.universal')
abort 'Release runtime check requires the official macOS release template' unless File.executable?(engine)
source = JSON.parse(File.read(File.join(File.dirname(engine), 'SOURCE.json')))
abort 'Release runtime template differs from its verified source' unless source.fetch('version') == '4.7.2.stable' && source.fetch('templates').fetch(File.basename(engine)) == Digest::SHA256.file(engine).hexdigest
Dir.mktmpdir('release-runtime-', File.join(root, '.tools')) do |directory|
  FileUtils.cp(engine, File.join(directory, 'EndlessReleaseCheck'))
  FileUtils.cp(executable, File.join(directory, 'EndlessReleaseCheck.pck'))
  FileUtils.cp(File.join(root, 'tests/release_runtime_probe.gd'), directory)
  scene = File.read(File.join(root, 'tests/release_runtime_probe.tscn')).sub('res://tests/release_runtime_probe.gd', 'res://release_runtime_probe.gd')
  File.write(File.join(directory, 'release_runtime_probe.tscn'), scene)
  File.write(File.join(directory, 'override.cfg'), "[application]\nrun/main_scene=\"res://release_runtime_probe.tscn\"\n")
  log, status = Open3.capture2e('./EndlessReleaseCheck', '--headless', '--quit-after', '4800', chdir: directory)
  puts log
  abort 'Packed release runtime regression failed' unless status.success? && log.include?('PASS: release-safe worker') && log.include?('debug=false') && log.include?('RELEASE_CROSSING 3') && !log.match?(/SCRIPT ERROR:|ERROR:|WARNING:/)
end
