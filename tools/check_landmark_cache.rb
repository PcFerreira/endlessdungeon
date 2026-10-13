#!/usr/bin/env ruby
require 'digest'
require 'json'

root = File.expand_path('..', __dir__)
catalog = JSON.parse(File.read(File.join(root, 'assets/landmark_cache/catalog.json')))
abort 'Missing landmark cache scenes' unless catalog['version'] == 1 && catalog.fetch('scenes').size >= 6
catalog.fetch('build_inputs').each do |path, hash|
  file = File.join(root, path.delete_prefix('res://'))
  abort "Stale landmark cache input: #{path}. Run tools/build_landmark_cache.gd." unless File.file?(file) && Digest::SHA256.file(file).hexdigest == hash
end
catalog.fetch('scenes').each_value do |path|
  file = File.join(root, path.delete_prefix('res://'))
  abort "Missing or changed landmark scene: #{path}" unless File.file?(file) && Digest::SHA256.file(file).hexdigest == catalog.fetch('scene_hashes').fetch(path)
end
puts "PASS: landmark cache freshness; #{catalog['scenes'].size} baked fixed components"
