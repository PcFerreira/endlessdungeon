#!/usr/bin/env ruby
require 'digest'
require 'fileutils'
require 'json'
require 'tempfile'

root = File.expand_path('..', __dir__)
version = '4.7.2.stable'
archive_name = 'Godot_v4.7.2-stable_export_templates.tpz'
url = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/#{archive_name}"
sha256 = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
base = File.join(root, '.tools/windows-templates')
archive = File.join(root, '.tools/web-templates', archive_name)
archive = File.join(base, archive_name) unless File.file?(archive)
target = File.join(base, version)
FileUtils.mkdir_p(target)
unless File.file?(archive)
  partial = archive + '.part'
  abort 'Template download failed' unless system('curl', '-fL', '--retry', '2', '-o', partial, url)
  File.rename(partial, archive)
end
abort 'Template archive SHA-256 mismatch' unless Digest::SHA256.file(archive).hexdigest == sha256
name = 'windows_release_x86_64.exe'
abort 'Template CRC check failed' unless system('unzip', '-tq', archive, "templates/#{name}")
abort 'Template extraction failed' unless system('unzip', '-j', '-o', archive, "templates/#{name}", '-d', target)
File.write(File.join(target, 'SOURCE.json'), JSON.pretty_generate({version: version, source: url, sha256: sha256, templates: {name => Digest::SHA256.file(File.join(target, name)).hexdigest}}) + "\n")
if RUBY_PLATFORM.include?('darwin')
  runtime = File.join(root, '.tools/release-runtime')
  FileUtils.mkdir_p(runtime)
  Tempfile.create(['godot-macos-templates', '.zip']) do |file|
    abort 'macOS template extraction failed' unless system('unzip', '-p', archive, 'templates/macos.zip', out: file.path)
    binary = 'godot_macos_release.universal'
    abort 'Release runtime extraction failed' unless system('unzip', '-j', '-o', file.path, "macos_template.app/Contents/MacOS/#{binary}", '-d', runtime)
    FileUtils.chmod(0755, File.join(runtime, binary))
    File.write(File.join(runtime, 'SOURCE.json'), JSON.pretty_generate({version: version, source: url, sha256: sha256, templates: {binary => Digest::SHA256.file(File.join(runtime, binary)).hexdigest}}) + "\n")
  end
end
puts "Verified official #{version} Windows x86_64 release template at #{target}"
