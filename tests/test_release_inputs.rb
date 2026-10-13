require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../tools/release_inputs'

class ReleaseInputsTest < Minitest::Test
  def test_configuration_and_baked_resources_cannot_change_during_export
    Dir.mktmpdir do |root|
      files = {
        'project.godot' => '[application]',
        'export_presets.cfg' => '[preset.0]',
        'scripts/game.gd' => 'extends Node',
        'config/dimensions/realm.json' => '{"map_version":1}',
        'assets/render_cache/catalog.json' => '{"version":1}',
        'assets/render_cache/body.scn' => 'baked body bytes',
        'assets/town_voxels/catalog.json' => '{"version":1}',
        'assets/town_voxels/japanese/house.scn' => 'voxel house bytes',
        'assets/town_voxels/runtime/japanese_house_flat.scn' => 'faceted house bytes',
        'assets/landmark_cache/catalog.json' => '{"version":1}',
        'assets/landmark_cache/castle_wall.scn' => 'fixed castle bytes',
        'assets/combat_audio/SOURCE.json' => '{"version":1}',
        'assets/combat_audio/spell.wav' => 'PCM bytes',
        'assets/combat_audio/spell.wav.import' => 'audio import metadata',
        'assets/biome_cutaway.gdshader' => 'shader_type spatial;'
      }
      files.each do |path, data|
        FileUtils.mkdir_p(File.dirname(File.join(root, path)))
        File.binwrite(File.join(root, path), data)
      end
      before = ReleaseInputs.snapshot(root)
      assert_equal files.keys.sort, before.keys
      %w[config/dimensions/realm.json assets/render_cache/catalog.json assets/render_cache/body.scn assets/landmark_cache/catalog.json assets/landmark_cache/castle_wall.scn assets/town_voxels/catalog.json assets/town_voxels/japanese/house.scn assets/town_voxels/runtime/japanese_house_flat.scn assets/combat_audio/SOURCE.json assets/combat_audio/spell.wav assets/combat_audio/spell.wav.import assets/biome_cutaway.gdshader].each do |path|
        File.binwrite(File.join(root, path), 'changed after export began')
        refute_equal before.fetch(path), ReleaseInputs.snapshot(root).fetch(path)
        File.binwrite(File.join(root, path), files.fetch(path))
      end
      File.write(File.join(root, 'config/dimensions/new_realm.json'), '{}')
      refute_equal before, ReleaseInputs.snapshot(root)
      File.delete(File.join(root, 'config/dimensions/new_realm.json'))
      File.delete(File.join(root, 'assets/render_cache/body.scn'))
      refute_equal before, ReleaseInputs.snapshot(root)
      assert_raises(Errno::ENOENT) { File.delete(File.join(root, 'project.godot')); ReleaseInputs.snapshot(root) }
    end
  end
end
