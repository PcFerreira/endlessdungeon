#!/usr/bin/env ruby
require 'digest'
require 'fileutils'
require 'json'
require 'zlib'

root = File.expand_path('..',__dir__)
Dir.chdir(root)
output = 'builds/web'
path = File.join(output,'index.html')
html = File.read(path)
unless html.include?('const missing = requiredFeatures(')
  original = html.dup
  html = html.sub("<script>\nconst GODOT_CONFIG", "<script type=\"module\">\nimport { requiredFeatures } from './lan-http-policy.js';\nconst GODOT_CONFIG")
  html = html.sub(/const missing = Engine\.getMissingFeatures\(\{\s*threads: GODOT_THREADS_ENABLED,\s*\}\);/, 'const missing = requiredFeatures(Engine.getMissingFeatures({ threads: GODOT_THREADS_ENABLED }), { protocol: window.location.protocol, hostname: window.location.hostname, threads: GODOT_THREADS_ENABLED });')
  abort 'Pinned Godot HTML launcher structure changed' if html == original || !html.include?('const missing = requiredFeatures(')
  File.write(path,html)
end
html = html.sub("import { requiredFeatures } from './lan-http-policy.js';", "import { requiredFeatures, launchArguments } from './lan-http-policy.js';")
unless html.include?('const WEB_LAUNCH_CONTEXT =')
  launch = File.read('tools/web_shell.html')[/const WEB_LAUNCH_CONTEXT =.*?\nconst engine/m].delete_suffix("\nconst engine")
  html = html.sub('const engine = new Engine(GODOT_CONFIG);',launch+"\nconst engine = new Engine(GODOT_CONFIG);")
end
File.write(path,html)
FileUtils.cp('tools/web_lan_policy.mjs',File.join(output,'lan-http-policy.js'))
report_path = File.join(output,'build-report.json')
report = JSON.parse(File.read(report_path))
['index.html','lan-http-policy.js'].each do |name|
  file = File.join(output,name)
  Zlib::GzipWriter.open(file+'.gz',Zlib::BEST_COMPRESSION) { |zip| zip.write(File.binread(file)) }
  report.fetch('files')[name] = {'bytes'=>File.size(file),'gzip_bytes'=>File.size(file+'.gz'),'sha256'=>Digest::SHA256.file(file).hexdigest}
end
hashes = ['tools/web_shell.html','tools/web_lan_policy.mjs'].to_h { |file| [file,Digest::SHA256.file(file).hexdigest] }
report['launcher_revision'] = Digest::SHA256.hexdigest(JSON.generate(hashes))
report['bytes'] = report.fetch('files').values.sum { |file| file.fetch('bytes') }
report['gzip_bytes'] = report.fetch('files').values.sum { |file| file.fetch('gzip_bytes') }
File.write(report_path,JSON.pretty_generate(report)+"\n")
puts "Updated private-LAN HTTP launcher; PCK and authority revision unchanged (#{report.fetch('content_revision')})"
