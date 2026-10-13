require 'fileutils'
require 'json'
require 'digest'

ROOT = File.expand_path('..', __dir__)
SOURCE = File.join(ROOT, 'import_assets')
manifest = []
copy = lambda do |relative, target|
  origin = File.join(SOURCE, relative)
  destination = File.join(ROOT, 'assets', target)
  FileUtils.mkdir_p(File.dirname(destination))
  FileUtils.cp(origin, destination)
  manifest << {source: relative, runtime: "assets/#{target}", sha256: Digest::SHA256.file(destination).hexdigest}
end

kaykit = 'KayKit_Dungeon_Pack_1.1_FREE'
%w[barrel_large crates_stacked banner_blue banner_patternA_red torch_mounted floor_tile_small floor_tile_small_broken_A].each do |name|
  path = "#{kaykit}/Assets/gltf/#{name}.gltf"
  copy.call(path, "environment/kaykit/#{name}.gltf")
  document = JSON.parse(File.read(File.join(SOURCE, path)))
  (document.fetch('buffers') + document.fetch('images')).each do |dependency|
    uri = dependency.fetch('uri')
    copy.call("#{kaykit}/Assets/gltf/#{uri}", "environment/kaykit/#{uri}")
  end
end
copy.call("#{kaykit}/License.txt", 'environment/kaykit/License.txt')

ruins = 'Ultimate Modular Ruins Pack - Aug 2021'
%w[Arch_Gothic Statue_Stag Pot1].each do |name|
  copy.call("#{ruins}/FBX/#{name}.fbx", "environment/quaternius/#{name}.fbx")
end
copy.call("#{ruins}/License.txt", 'environment/quaternius/License.txt')

%w[fire_01 magic_01 smoke_01].each do |name|
  copy.call("kenney_particle-pack/PNG (Transparent)/#{name}.png", "particles/#{name}.png")
end
copy.call('kenney_particle-pack/License.txt', 'particles/License.txt')

Dir.glob(File.join(SOURCE, '*.{ogg,mp3}')).sort.each do |path|
  copy.call(File.basename(path), "music/#{File.basename(path)}")
end
copy.call('sound_attribution.txt', 'music/source_attribution.txt')
ui = 'free_packs/kenney_ui_pack_rpg_expansion'
%w[panel_blue panelInset_blue buttonLong_blue buttonLong_blue_pressed buttonSquare_brown buttonSquare_brown_pressed buttonSquare_blue buttonSquare_blue_pressed].each do |name|
  copy.call("#{ui}/PNG/#{name}.png", "ui/rpg/#{name}.png")
end
%w[Back Red Blue Green].each do |color|
  %w[Left Mid Right].each do |part|
    name = "bar#{color}_horizontal#{part}"
    source_name = color == 'Blue' && part == 'Mid' ? 'barBlue_horizontalBlue' : name
    copy.call("#{ui}/PNG/#{source_name}.png", "ui/rpg/#{name}.png")
  end
end
copy.call("#{ui}/license.txt", 'ui/rpg/License.txt')
borders = 'free_packs/kenney_fantasy_ui_borders'
copy.call("#{borders}/PNG/Double/Transparent center/panel-transparent-center-001.png", 'ui/fantasy/frame.png')
copy.call("#{borders}/PNG/Double/Divider/divider-000.png", 'ui/fantasy/divider.png')
copy.call("#{borders}/License.txt", 'ui/fantasy/License.txt')
File.write(File.join(ROOT, 'assets', 'source_manifest.json'), JSON.pretty_generate(manifest.uniq) + "\n")
puts "Adopted #{manifest.uniq.size} source files. Originals remain in import_assets/."
