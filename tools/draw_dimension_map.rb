require 'json'
require 'cgi'
require 'fileutils'
require 'base64'
input = ARGV[0] || 'config/dimensions/morrowmere.json'
data = JSON.parse(File.read(input))
output = ARGV[1] || "docs/maps/#{data.fetch('id')}.svg"
scale = 780.0 / data.fetch('bounds')[2]
x0, y0 = 28, 145
xy = ->(point) { [x0 + point[0]*scale, y0 + point[1]*scale] }
esc = ->(text) { CGI.escapeHTML(text.to_s) }
height = [1080, 232 + data.fetch('sites').size * 17].max
svg = ["<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1280\" height=\"#{height}\" viewBox=\"0 0 1280 #{height}\" role=\"img\" aria-labelledby=\"title desc\">", "<title id=\"title\">#{esc.call(data['name'])}: authored dimension map</title>", "<desc id=\"desc\">#{data.fetch('areas').size} named areas, fixed roads, #{data.fetch('sites').size} destinations and the arrival and return portal. Original game design, with north at the top.</desc>", "<rect width=\"1280\" height=\"#{height}\" fill=\"#151f2b\"/>", '<g font-family="system-ui, sans-serif" fill="#eef1e7">', "<text x=\"28\" y=\"53\" font-size=\"35\">#{esc.call(data['name'])}</text>", "<text x=\"28\" y=\"84\" fill=\"#b8c8d3\" font-size=\"18\">#{esc.call(data['subtitle'])} · #{data['bounds'][2]} × #{data['bounds'][3]} cells · Map version #{data['map_version']}</text>", '<text x="28" y="114" fill="#b8c8d3" font-size="16">Fixed geography · Streamed nearby chunks · N ↑</text>', "<rect x=\"#{x0}\" y=\"#{y0}\" width=\"780\" height=\"780\" rx=\"4\" fill=\"#294454\" stroke=\"#6c8291\"/>"]
if data.key?('terrain')
 folder="artifacts/dimension-maps/#{data.fetch('id')}-v#{data.fetch('map_version')}"
 raster=JSON.parse(File.read(File.join(folder,'terrain.json')))
 abort 'Terrain raster is stale; rerun tools/export_dimension_map.gd' unless raster.fetch('definition')==data
 png=Base64.strict_encode64(File.binread(File.join(folder,'terrain.png')))
 svg << "<image x=\"#{x0}\" y=\"#{y0}\" width=\"780\" height=\"780\" href=\"data:image/png;base64,#{png}\"/>"
else
 data.fetch('areas').each do |area|
  x,y,w,h=area.fetch('bounds'); px,py=xy.call([x,y])
  svg << "<rect x=\"#{px}\" y=\"#{py}\" width=\"#{w*scale}\" height=\"#{h*scale}\" fill=\"##{area['map_color']}\"/>"
 end
end
data.fetch('routes').each do |route|
 points=route.fetch('path').map { |point| xy.call(point).join(',') }.join(' ')
 svg << "<polyline points=\"#{points}\" fill=\"none\" stroke=\"#d8c7a1\" stroke-width=\"#{route['width']==5 ? 3 : 1.6}\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>"
end
data.fetch('areas').each do |area|
 px,py=xy.call(area.fetch('label_cell'))
 svg << "<text x=\"#{px}\" y=\"#{py-23}\" text-anchor=\"middle\" font-size=\"17\" font-weight=\"600\" paint-order=\"stroke\" stroke=\"#25322b\" stroke-width=\"3\">#{esc.call(area['name'])}</text>"
end
data.fetch('encounters', []).each do |ground|
 px,py=xy.call(ground.fetch('cell'))
 svg << "<circle cx=\"#{px}\" cy=\"#{py}\" r=\"4\" fill=\"#d97b6b\" stroke=\"#4e2927\" stroke-width=\"1\"/>"
end
svg << "<text x=\"28\" y=\"972\" font-size=\"18\">#{data.fetch('sites').size} destinations · #{data.fetch('sites').sum { |site| site.fetch('residents', []).size }} residents · #{data.fetch('encounters', []).size} encounter grounds</text>"
svg << "<text x=\"28\" y=\"1001\" font-size=\"15\" fill=\"#d97b6b\">● Wilderness encounters · #{data.fetch('encounters', []).sum { |ground| ground.fetch('members').size }} authored monsters</text>"
svg << '<text x="28" y="1029" font-size="14" fill="#b8c8d3">Original communities and landmarks inspired by bright fantasy and old-world traces.</text>'
svg << '<text x="846" y="145" font-size="23">Authored destinations</text>'
data.fetch('sites').each_with_index do |site,index|
 px,py=xy.call(site.fetch('cell')); color=site['type']=='city' ? '#ffe2a0' : '#e8edf3'
 svg << "<circle cx=\"#{px}\" cy=\"#{py}\" r=\"9\" fill=\"#{color}\" stroke=\"#23313a\" stroke-width=\"2\"/><text x=\"#{px}\" y=\"#{py+3.5}\" text-anchor=\"middle\" fill=\"#19232a\" font-size=\"10\" font-weight=\"700\">#{index+1}</text>"
 ly=178+index*17
 svg << "<text x=\"846\" y=\"#{ly}\" fill=\"#{color}\" font-size=\"12\">#{index+1}. #{esc.call(site['name'])}</text><text x=\"1238\" y=\"#{ly}\" text-anchor=\"end\" fill=\"#9eafb8\" font-size=\"10\">#{esc.call(site['type'].tr('_', ' '))}</text>"
end
px,py=xy.call(data.fetch('return_portal'))
svg << "<circle cx=\"#{px}\" cy=\"#{py}\" r=\"9\" fill=\"#d2a2f3\" stroke=\"#302146\" stroke-width=\"2\"/><text x=\"#{px+16}\" y=\"#{py+6}\" font-size=\"14\" paint-order=\"stroke\" stroke=\"#25322b\" stroke-width=\"3\">#{esc.call(data.fetch('return_portal_name', 'Return gate'))}</text>"
svg += ["<text x=\"846\" y=\"#{height-40}\" font-size=\"15\" fill=\"#d2a2f3\">● Arrival and return gate</text>", "<text x=\"846\" y=\"#{height-16}\" font-size=\"14\" fill=\"#b8c8d3\">Design atlas. In-game landmark discovery is separate.</text>", '</g></svg>']
FileUtils.mkdir_p(File.dirname(output))
File.write(output,svg.join("\n")+"\n")
puts "Wrote #{output} from #{input}"
