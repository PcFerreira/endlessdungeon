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
expansion = {
  'quaternius_cube_world' => ['Environment/glTF', %w[Tree_1 Tree_2 Tree_3 DeadTree_1 DeadTree_2 DeadTree_3 Bush Mushroom Rock1 Rock2 Flowers_1 Flowers_2 Fence_Center Fence_Corner Fence_End Cart Plant_2], 'gltf'],
  'kenney_fantasy_town_kit' => ['Models/GLB format', %w[stall stall-bench lantern], 'glb'],
  'kenney_survival_kit' => ['Models/GLB format', %w[tent bedroll campfire-pit signpost-single tree-log], 'glb'],
  'quaternius_fantasy_props' => ['Exports/glTF', %w[BookStand Book_Simplified_Single Bookcase_2 Scroll_1 Workbench Anvil Lantern_Wall], 'gltf'],
  'kaykit_furniture' => ['content/addons/kaykit_furniture_bits/Assets/gltf', %w[bed_single_A table_medium], 'gltf'],
  'kenney_modular_cave_kit' => ['Models/GLB format', %w[template-floor template-wall template-wall-corner], 'glb'],
  'kenney_nature_kit' => ['Models/GLTF format', %w[mushroom_tanTall stump_old], 'glb']
}
adopt = nil
adopt = lambda do |relative|
  target = relative.sub('free_packs/', 'expansion/')
  next if manifest.any? { |record| record[:runtime] == "assets/#{target}" }
  copy.call(relative, target)
  extension = File.extname(relative)
  next unless %w[.gltf .glb].include?(extension)
  contents = File.binread(File.join(SOURCE, relative))
  document = JSON.parse(extension == '.glb' ? contents.byteslice(20, contents.byteslice(12, 4).unpack1('V')) : contents)
  (document.fetch('buffers', []) + document.fetch('images', [])).each do |dependency|
    uri = dependency['uri']
    next unless uri && !uri.start_with?('data:')
    origin = File.expand_path(uri, File.join(SOURCE, File.dirname(relative)))
    adopt.call(origin.delete_prefix(SOURCE + '/'))
  end
end
expansion.each do |pack, (directory, names, extension)|
  names.each { |name| adopt.call("free_packs/#{pack}/#{directory}/#{name}.#{extension}") }
  %w[LICENSE_CC0-1.0.txt LICENSE_SOURCE.md SOURCE.json].each { |name| adopt.call("free_packs/#{pack}/#{name}") }
  Dir.glob(File.join(SOURCE, 'free_packs', pack, '**', '*')).select { |path| File.file?(path) && File.basename(path).match?(/licen[sc]e/i) }.each do |path|
    adopt.call(path.delete_prefix(SOURCE + '/'))
  end
end
%w[Character_Female_1 Character_Female_2 Character_Male_1 Character_Male_2].each do |name|
  adopt.call("free_packs/quaternius_cube_world/Characters/glTF/#{name}.gltf")
end
File.write(File.join(ROOT, 'assets', 'source_manifest.json'), JSON.pretty_generate(manifest.uniq) + "\n")
puts "Adopted #{manifest.uniq.size} source files. Originals remain in import_assets/."
