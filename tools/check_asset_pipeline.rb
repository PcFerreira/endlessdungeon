require 'open3'
require_relative 'import_assets'

root = File.expand_path('..', __dir__)
candidates = [ENV['GODOT_BIN'], File.join(root, '.tools/Godot.app/Contents/MacOS/Godot'), '/Applications/Godot.app/Contents/MacOS/Godot']
candidates += ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).flat_map { |dir| %w[godot godot4].map { |name| File.join(dir, name) } }
engine = candidates.compact.find { |path| File.executable?(path) }
abort 'Godot is required. Set GODOT_BIN to its executable.' unless engine
config = JSON.parse(File.read(File.join(root, 'config/asset_imports.json')))
scan = AssetImporter.new(root, config).scan
Dir.mktmpdir('endless-pipeline-check-') do |project|
  FileUtils.mkdir_p(File.join(project, 'import_assets/free_packs'))
  File.write(File.join(project, 'import_assets/.gdignore'), '')
  Dir.glob(File.join(root, 'assets/imported/packs/*')).each { |pack| FileUtils.cp_r(pack, File.join(project, 'import_assets/free_packs')) }
  FileUtils.cp_r(File.join(root, 'lore'), File.join(project, 'lore'))
  extras = [['fsp_modular_temple', 'model', '.obj'], ['kenney_ui_pack_rpg_expansion', 'texture', '.png'], ['kenney_interface_sounds', 'audio', '.ogg']]
  extras.each do |pack, kind, extension|
    FileUtils.cp_r(File.join(root, 'import_assets/free_packs', pack), File.join(project, 'import_assets/free_packs'))
    entry = scan['assets'].find { |a| a['pack'] == pack && a['kind'] == kind && a['relative'].end_with?(extension) }
    abort "Missing real fixture asset: #{pack}" unless entry
    config['rules'] << {'pack' => pack, 'include' => [entry['relative']], 'tags' => ['pipeline-fixture']}
  end
  FileUtils.mkdir_p(File.join(project, 'lore/content'))
  File.write(File.join(project, 'lore/content/pipeline-book.md'), "---\nid: pipeline_new_book\nkind: book\ntitle: Pipeline Test Book\n---\nA new authored passage.\n")
  File.write(File.join(project, 'lore/content/pipeline-line.json'), JSON.generate({id: 'pipeline_new_line', kind: 'dialogue', speaker: 'new_role', event: 'greeting', text: 'A new authored line.'}))
  AssetImporter.new(project, config).build
  FileUtils.mkdir_p(File.join(project, 'scripts'))
  FileUtils.mkdir_p(File.join(project, 'tests'))
  FileUtils.cp(File.join(root, 'scripts/asset_registry.gd'), File.join(project, 'scripts'))
  FileUtils.cp(File.join(root, 'scripts/scenery.gd'), File.join(project, 'scripts'))
  FileUtils.cp(File.join(root, 'scripts/asset_profiles.gd'), File.join(project, 'scripts'))
  FileUtils.cp(File.join(root, 'tests/test_asset_registry.gd'), File.join(project, 'tests'))
  FileUtils.cp(File.join(root, 'tests/test_dynamic_scenery.gd'), File.join(project, 'tests'))
  File.write(File.join(project, 'project.godot'), "config_version=5\n[application]\nconfig/name=\"Isolated Asset Pipeline Check\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
  output, status = Open3.capture2e(engine, '--headless', '--editor', '--path', project, '--import')
  warnings = output.lines.select { |line| line.start_with?('WARNING:') }
  unexpected = warnings.reject { |line| line.include?('OBJ: Ambient light for material') && line.include?('is ignored in PBR') }
  abort output unless status.success? && !output.match?(/SCRIPT ERROR:|ERROR:/) && unexpected.empty?
  puts "PASS: isolated Godot import; #{warnings.size} expected legacy OBJ ambient-light warnings"
  File.write(File.join(project, 'lore/content/rebuild.json'), JSON.generate({id: 'pipeline_rebuild_note', kind: 'lore', text: 'A changed catalogue must regenerate model textures.'}))
  AssetImporter.new(project, config).build
  output, status = Open3.capture2e(engine, '--headless', '--editor', '--path', project, '--import')
  warnings = output.lines.select { |line| line.start_with?('WARNING:') }
  unexpected = warnings.reject { |line| line.include?('OBJ: Ambient light for material') && line.include?('is ignored in PBR') }
  abort output unless status.success? && !output.match?(/SCRIPT ERROR:|ERROR:/) && unexpected.empty?
  FileUtils.rm_rf(File.join(project, 'import_assets'))
  FileUtils.rm_rf(File.join(project, 'lore'))
  puts 'PASS: changed catalogue rebuild followed by a normal editor import regenerates extracted model textures'
  output, status = Open3.capture2e(engine, '--headless', '--path', project, '--script', 'tests/test_asset_registry.gd', '--quit-after', '60', '--', '--pipeline-fixture')
  abort output unless status.success? && !output.match?(/SCRIPT ERROR:|ERROR:|WARNING:/) && output.include?('PASS:')
  puts output.lines.grep(/^PASS:/)
  output, status = Open3.capture2e(engine, '--headless', '--path', project, '--script', 'tests/test_dynamic_scenery.gd', '--quit-after', '60', '--', '--pipeline-fixture')
  abort output unless status.success? && !output.match?(/SCRIPT ERROR:|ERROR:|WARNING:/) && output.include?('PASS:')
  puts output.lines.grep(/^PASS:/)
  puts 'PASS: real GLB, glTF, OBJ, PNG and OGG resources; future Markdown/JSON lore; runtime works after removing authoring sources'
end
