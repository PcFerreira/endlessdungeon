#!/usr/bin/env ruby
require 'digest'
require 'json'

root = File.expand_path('..', __dir__)
catalog = JSON.parse(File.read(File.join(root, 'assets/render_cache/catalog.json')))
abort 'Missing render cache scenes' unless catalog['version'] == 1 && catalog.fetch('scenes').size >= 302
catalog.fetch('build_inputs').each do |path, hash|
  file = File.join(root, path.delete_prefix('res://'))
  abort "Stale render cache input: #{path}. Run tools/build_render_cache.gd before exporting." unless File.file?(file) && Digest::SHA256.file(file).hexdigest == hash
end
catalog.fetch('scenes').each_value do |path|
  file = File.join(root, path.delete_prefix('res://'))
  abort "Missing or changed baked scene: #{path}" unless File.file?(file) && Digest::SHA256.file(file).hexdigest == catalog.fetch('scene_hashes').fetch(path)
end
puts "PASS: render cache freshness; #{catalog['scenes'].size} baked source scenes"
load File.join(__dir__, 'check_landmark_cache.rb') if File.file?(File.join(root, 'scripts/landmark_cache.gd'))
