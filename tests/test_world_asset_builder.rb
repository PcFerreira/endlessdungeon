require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'fileutils'
require_relative '../tools/build_world_assets'

class WorldAssetBuilderTest < Minitest::Test
  def test_primary_coverage_semantics_and_non_destructive_outputs
    Dir.mktmpdir do |root|
      pack = File.join(root, 'import_assets/free_packs/test_grove')
      FileUtils.mkdir_p(pack)
      source = {'id'=>'test_grove', 'title'=>'Grove', 'author'=>'Fixture', 'source'=>'https://example.com/grove', 'license'=>'CC0-1.0', 'license_url'=>'https://creativecommons.org/publicdomain/zero/1.0/'}
      File.write(File.join(pack, 'SOURCE.json'), JSON.generate(source))
      %w[Tree.glb Tree.obj Column.glb Apple.glb Atlas.png].each { |name| File.write(File.join(pack,name), name) }
      config = {'version'=>1, 'packs'=>{'test_grove'=>{'include'=>['*.glb']}}, 'roles'=>{'canopy'=>{'packs'=>['test_grove'], 'include'=>['Tree*']}}, 'libraries'=>{'architecture'=>{'packs'=>['test_grove'], 'include'=>['Column*']}}}
      builder = WorldAssetBuilder.new(root, config)
      catalog, inventory, imports = builder.documents
      assert_equal ['test_grove/Tree.glb'], catalog['roles']['canopy']
      assert_equal ['test_grove/Column.glb'], catalog['libraries']['architecture']
      statuses = inventory['assets'].to_h { |entry| [entry['id'],entry['status']] }
      assert_equal 'alternate_format', statuses['test_grove/Tree.obj']
      assert_equal 'support_resource', statuses['test_grove/Atlas.png']
      assert_equal 'unassigned_library', statuses['test_grove/Apple.glb'], 'Unclassified assets must never become random scenery'
      assert imports['rules'].all? { |rule| rule['tags'].include?('world-construction') }
      assert_equal 'Apple.glb', File.read(File.join(pack,'Apple.glb'))
      builder.build
      assert builder.build(check: true)
      File.write(File.join(pack,'Tree.glb'), 'updated geometry')
      assert_raises(WorldAssetBuilder::Error) { builder.build(check: true) }
    end
  end
end
