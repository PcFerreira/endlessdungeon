require 'minitest/autorun'
require 'tmpdir'
require_relative '../tools/content_editor/import_asset'

class ContentEditorImportTest < Minitest::Test
  def test_selected_source_is_staged_once_with_original_provenance
    Dir.mktmpdir('endless-editor-import') do |root|
      FileUtils.mkdir_p(File.join(root, 'config'))
      source = File.join(root, 'import_assets/sample/content')
      FileUtils.mkdir_p(source)
      metadata = {'id' => 'sample', 'title' => 'Sample', 'author' => 'Fixture author', 'source' => 'https://example.invalid/sample', 'license' => 'CC0-1.0', 'license_url' => 'https://creativecommons.org/publicdomain/zero/1.0/'}
      File.write(File.join(source, '../SOURCE.json'), JSON.generate(metadata))
      File.write(File.join(source, '../LICENSE.txt'), 'This authored test fixture is dedicated to the public domain under CC0-1.0.')
      original = '<svg xmlns="http://www.w3.org/2000/svg" width="8" height="8"><rect width="8" height="8" fill="red"/></svg>'
      File.write(File.join(source, 'icon[1].svg'), original)
      File.write(File.join(root, 'config/asset_imports.json'), JSON.generate({'version' => 1, 'rules' => [], 'lore_sources' => []}))
      adoption = EditorAssetImport.new(root)
      adoption.stage('sample/content/icon[1].svg')
      adoption.stage('sample/content/icon[1].svg')
      config = JSON.parse(File.read(File.join(root, 'config/asset_imports.json')))
      fragment = JSON.parse(File.read(File.join(root, 'config/editor_asset_imports.json')))
      assert_equal ['config/editor_asset_imports.json'], config['rule_files']
      assert_equal 1, fragment['rules'].size
      result = AssetImporter.new(root, config).build
      asset = result['assets'].find { |entry| entry['id'] == 'sample/content/icon[1].svg' }
      assert asset
      assert_equal 'Fixture author', asset['author']
      assert_equal 'CC0-1.0', asset['license']
      assert_equal original, File.read(File.join(source, 'icon[1].svg'))
      assert_equal original, File.read(File.join(root, 'assets/imported/packs/sample/content/icon[1].svg'))
      assert_raises(AssetImporter::Error) { adoption.stage('unknown/not-a-source.svg') }
      assert_equal config, JSON.parse(File.read(File.join(root, 'config/asset_imports.json')))
    end
  end
end
