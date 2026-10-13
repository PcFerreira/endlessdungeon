require 'open3'
require_relative 'import_assets'

root = File.expand_path('..',__dir__)
engine = File.join(root,'.tools/Godot.app/Contents/MacOS/Godot')
Dir.mktmpdir('endless-world-lore-cache-') do |project|
  source = File.join(project,'import_assets/free_packs')
  FileUtils.mkdir_p(source)
  FileUtils.cp_r(File.join(root,'assets/imported/packs/quaternius_cube_world'),source)
  File.write(File.join(project,'import_assets/.gdignore'),'')
  FileUtils.mkdir_p(File.join(project,'lore/content'))
  config = {'version'=>1,'rules'=>[{'pack'=>'quaternius_cube_world','kinds'=>['model'],'include'=>['Environment/glTF/Tree_1.gltf']}],'lore_sources'=>[{'glob'=>'lore/content/*.json','format'=>'entries'}]}
  importer = AssetImporter.new(project,config)
  importer.build
  File.write(File.join(project,'project.godot'),"config_version=5\n[application]\nconfig/name=\"World Lore Cache Check\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
  output,status = Open3.capture2e(engine,'--headless','--editor','--path',project,'--quit')
  abort output unless status.success? && !output.match?(/ERROR:|WARNING:/)
  model = File.join(project,'assets/imported/packs/quaternius_cube_world/Environment/glTF/Tree_1.gltf')
  sidecar = File.binread(model+'.import')
  textures = Dir.glob(File.join(File.dirname(model),'Tree_1*.png'))
  raise 'Real embedded model must extract at least one texture' if textures.empty?
  hashes = textures.to_h { |path| [path,Digest::SHA256.file(path).hexdigest] }
  File.write(File.join(project,'lore/content/new.json'),JSON.generate({'id'=>'world_cache_note','kind'=>'lore','text'=>'A metadata-only world note.'}))
  importer.build
  raise 'Lore-only rebuild discarded model cache' unless File.binread(model+'.import')==sidecar && hashes.all? { |path,sha| File.file?(path) && Digest::SHA256.file(path).hexdigest==sha }
  output,status = Open3.capture2e(engine,'--headless','--editor','--path',project,'--quit')
  abort output unless status.success? && !output.match?(/ERROR:|WARNING:/)
  FileUtils.mkdir_p(File.join(project,'scripts'))
  FileUtils.cp(File.join(root,'scripts/asset_registry.gd'),File.join(project,'scripts'))
  script = <<~GDSCRIPT
    extends SceneTree
    const Registry = preload("res://scripts/asset_registry.gd")
    func _initialize() -> void:
      var registry := Registry.new()
      var model := registry.instantiate("quaternius_cube_world/Environment/glTF/Tree_1.gltf")
      assert(model != null)
      var textures := 0
      for mesh in model.find_children("*", "MeshInstance3D", true, false):
        for surface in range(mesh.mesh.get_surface_count()):
          var material = mesh.get_active_material(surface)
          if material is StandardMaterial3D and material.albedo_texture != null:
            assert(material.albedo_texture.get_width() > 0)
            textures += 1
      assert(textures > 0)
      model.free()
      print("PASS: real model and extracted textures survive lore-only rebuild and editor restart")
      quit()
  GDSCRIPT
  File.write(File.join(project,'check.gd'),script)
  output,status = Open3.capture2e(engine,'--headless','--path',project,'--script','check.gd','--quit-after','60')
  abort output unless status.success? && !output.match?(/ERROR:|WARNING:/) && output.include?('PASS:')
  puts output.lines.grep(/^PASS:/)
end
