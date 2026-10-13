require 'json'
require 'digest'
require 'fileutils'
require 'open3'

root = File.expand_path('..', __dir__)
output = File.join(root, 'assets/combat_audio')
FileUtils.mkdir_p(output)
sources = [
  {id: 'rubberduck_rpg', title: '80 CC0 RPG SFX', author: 'rubberduck', source: 'https://opengameart.org/content/80-cc0-rpg-sfx', license: 'CC0-1.0', license_url: 'https://creativecommons.org/publicdomain/zero/1.0/', attribution_required: false, attribution_text: '80 CC0 RPG SFX by rubberduck, OpenGameArt.org. CC0-1.0.'},
  {id: 'jaggedstone_magic', title: 'Magic Spell SFX', author: 'JaggedStone', source: 'https://opengameart.org/content/magic-spell-sfx', license: 'CC0-1.0', license_url: 'https://creativecommons.org/publicdomain/zero/1.0/', attribution_required: false, attribution_text: 'Magic Spell SFX by JaggedStone, OpenGameArt.org. CC0-1.0.'}
]
sources.each do |source|
  directory = File.join(root, 'import_assets/combat_audio', source[:id])
  originals = Dir[File.join(directory, 'original/*.ogg')].sort.to_h { |path| [File.basename(path), Digest::SHA256.file(path).hexdigest] }
  archive = File.join(directory, '80-CC0-RPG-SFX.zip')
  metadata = source.merge(acquired_on: '2026-10-13', original_sha256: originals, source_asset_changes: 'Original downloads unchanged. Runtime PCM derivatives have trim/normalization recipes in assets/combat_audio/SOURCE.json.')
  if File.file?(archive)
    metadata[:download] = {url: 'https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip', bytes: File.size(archive), sha256: Digest::SHA256.file(archive).hexdigest, archive_crc_checked: true}
  else
    metadata[:downloads] = (1..7).map { |index| "https://opengameart.org/sites/default/files/magical_#{index}#{[1, 6, 7].include?(index) ? '_0' : ''}.ogg" }
  end
  File.write(File.join(directory, 'SOURCE.json'), JSON.pretty_generate(metadata) + "\n")
  File.write(File.join(directory, 'LICENSE.md'), "# #{source[:title]}\n\n#{source[:title]} by #{source[:author]} is offered under [CC0 1.0 Universal](#{source[:license_url]}). See the [author's source page](#{source[:source]}) and the retained SOURCE_PAGE.html for the published license. Attribution is not required; this project credits the creator. Original downloads are preserved, and runtime conversion recipes are recorded separately.\n")
end
selections = {
  'arcane' => ['rubberduck_rpg', 'spell_01.ogg', 0.7],
  'lightning' => ['rubberduck_rpg', 'spell_02.ogg', 0.6],
  'ember' => ['rubberduck_rpg', 'spell_fire_01.ogg', 0.8],
  'explosion' => ['rubberduck_rpg', 'spell_fire_04.ogg', 0.9],
  'meteor' => ['rubberduck_rpg', 'spell_fire_03.ogg', 1.0],
  'blade_01' => ['rubberduck_rpg', 'blade_01.ogg', 0.4],
  'blade_02' => ['rubberduck_rpg', 'blade_02.ogg', 0.4],
  'blade_03' => ['rubberduck_rpg', 'blade_03.ogg', 0.45],
  'frost' => ['jaggedstone_magic', 'magical_6.ogg', 0.85],
  'blink' => ['jaggedstone_magic', 'magical_3.ogg', 0.6],
  'mend' => ['jaggedstone_magic', 'magical_1.ogg', 0.9],
  'rune' => ['jaggedstone_magic', 'magical_2.ogg', 0.75],
  'second_wind' => ['jaggedstone_magic', 'magical_5.ogg', 0.7]
}
records = selections.map do |name, (pack, file, duration)|
  source = File.join(root, 'import_assets/combat_audio', pack, 'original', file)
  target = File.join(output, "#{name}.wav")
  filters = "silenceremove=start_periods=1:start_threshold=-48dB:start_duration=0.005,atrim=duration=#{duration},asetpts=PTS-STARTPTS,afade=t=out:st=#{duration - 0.07}:d=0.07"
  _, analysis, status = Open3.capture3('ffmpeg', '-hide_banner', '-i', source, '-af', "#{filters},volumedetect", '-f', 'null', '-')
  abort "Audio analysis failed: #{file}" unless status.success?
  peak = analysis[/max_volume: (-?[\d.]+) dB/, 1]
  abort "Silent or invalid source: #{file}" unless peak
  gain = -3.0 - peak.to_f
  arguments = ['ffmpeg', '-v', 'error', '-y', '-i', source, '-af', "#{filters},volume=#{gain}dB", '-ar', '44100', '-ac', '1', '-c:a', 'pcm_s16le', '-map_metadata', '-1', target]
  abort "Conversion failed: #{file}" unless system(*arguments)
  {id: name, path: "res://assets/combat_audio/#{name}.wav", source: source.delete_prefix(root + '/'), source_sha256: Digest::SHA256.file(source).hexdigest, sha256: Digest::SHA256.file(target).hexdigest, filter: "#{filters},volume=#{gain}dB", format: 'PCM s16le / 44100 Hz / mono', license: 'CC0-1.0'}
end
File.write(File.join(output, 'SOURCE.json'), JSON.pretty_generate({version: 1, sources: sources, assets: records}) + "\n")
puts "Prepared #{records.size} normalized combat one-shots with original-source hashes"
