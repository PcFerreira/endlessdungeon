#!/usr/bin/env ruby
require 'digest'
require 'fileutils'
require 'json'

root = File.expand_path('..', __dir__)
version = '4.7.2.stable'
archive_name = 'Godot_v4.7.2-stable_export_templates.tpz'
url = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/#{archive_name}"
sha256 = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
base = File.join(root, '.tools/web-templates')
archive = File.join(base, archive_name)
target = File.join(base, version)
FileUtils.mkdir_p(base)
unless File.file?(archive)
  partial = archive + '.part'
  abort 'Template download failed' unless system('curl', '-fL', '--retry', '2', '-o', partial, url)
  File.rename(partial, archive)
end
abort 'Template archive SHA-256 mismatch' unless Digest::SHA256.file(archive).hexdigest == sha256
entries = ['web_nothreads_debug.zip', 'web_nothreads_release.zip']
FileUtils.mkdir_p(target)
entries.each do |name|
  abort "Template extraction failed: #{name}" unless system('unzip', '-j', '-o', archive, "templates/#{name}", '-d', target)
  abort "Template CRC check failed: #{name}" unless system('unzip', '-tq', File.join(target, name))
end
hashes = entries.to_h { |name| [name, Digest::SHA256.file(File.join(target, name)).hexdigest] }
File.write(File.join(target, 'SOURCE.json'), JSON.pretty_generate({version: version, source: url, sha256: sha256, templates: hashes, release: 'https://godotengine.org/download/archive/4.7.2-stable/'} ) + "\n")
puts "Verified official #{version} single-thread Web templates at #{target}"
