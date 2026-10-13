require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require_relative '../tools/import_assets'

class AssetImporterTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('asset-pipeline-test-')
    @config = {'rules' => [{'pack' => '*', 'include' => ['**/*.gltf', '**/*.glb'], 'tags' => ['scenery']}], 'lore_sources' => [{'glob' => 'lore/**/*.md', 'format' => 'markdown'}, {'glob' => 'lore/content/**/*.json', 'format' => 'entries'}]}
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def write(path, content)
    path = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(path))
    File.binwrite(path, content)
  end

  def pack(id, uri = 'mesh%20data.bin')
    base = "import_assets/free_packs/#{id}"
    write("#{base}/SOURCE.json", JSON.generate({id: id, title: id, author: 'Fixture creator', source: 'https://example.org/fixture', license: 'CC0-1.0', license_url: 'https://creativecommons.org/publicdomain/zero/1.0/', categories: ['Trees']}))
    write("#{base}/LICENSE.txt", 'Fixture license notice')
    write("#{base}/models/model.gltf", JSON.generate({asset: {version: '2.0'}, buffers: [{uri: uri, byteLength: 4}], images: [{uri: '../textures/color.png'}]}))
    write("#{base}/models/mesh data.bin", 'DATA')
    write("#{base}/textures/color.png", 'TEXTURE')
  end

  def test_discovery_dependencies_credits_lore_and_incremental_build
    pack('new_pack')
    write('lore/content/letter.md', "---\nid: letter_home\nkind: book\ntitle: A Letter Home\ntags: [winter]\n---\nDear traveler,\n\nCome home.\n")
    write('lore/content/rumors.json', JSON.generate([{id: 'rumor_bridge', kind: 'dialogue', speaker: 'new_role', event: 'greeting', text: 'The bridge is open.', tags: ['roads']}]))
    write('lore/new_books.md', "## Old Map\n\nBook ID: `book_old_map`. Author: Ada. Placement: shelf.\n\n> Follow the river.\n")
    write('lore/new_dialogue.md', "| ID | Speaker | Event | Condition | Text |\n| --- | --- | --- | --- | --- |\n| `new_line` | `new_role` | `ambient` | Any | Welcome. |\n")
    write('lore/content/external.txt', 'External fixture license')
    write('lore/content/external.json', JSON.generate({id: 'external_book', kind: 'book', title: 'External Book', author: 'External Author', text: 'Licensed passage.', license: 'CC-BY-4.0', license_url: 'https://creativecommons.org/licenses/by/4.0/', source: 'https://example.org/book', license_file: 'external.txt', attribution_text: 'External Book by External Author, CC BY 4.0.'}))
    @config['overrides'] = {'new_pack/models/model.gltf' => {'aliases' => ['oak'], 'scale' => 2.0}}
    importer = AssetImporter.new(@root, @config)
    scan = importer.scan
    assert_equal 5, scan['assets'].count { |a| a['kind'] == 'text' }
    assert_equal 1, scan['assets'].count { |a| a['kind'] == 'model' }
    catalog = importer.build
    model = catalog['assets'].find { |a| a['kind'] == 'model' }
    assert_includes model['tags'], 'scenery'
    assert_includes model['tags'], 'trees'
    assert_equal ['oak'], model['aliases']
    assert File.file?(File.join(@root, 'assets/imported/packs/new_pack/models/mesh data.bin'))
    assert File.file?(File.join(@root, 'assets/imported/packs/new_pack/textures/color.png'))
    assert File.file?(File.join(@root, 'assets/imported/packs/new_pack/LICENSE.txt'))
    assert_includes File.read(File.join(@root, 'assets/imported/CREDITS.md')), 'Fixture creator'
    assert File.file?(File.join(@root, 'assets/imported/sources/lore/content/external.txt'))
    assert_includes File.read(File.join(@root, 'assets/imported/CREDITS.md')), 'CC BY 4.0'
    assert_equal "Dear traveler,\n\nCome home.\n", catalog['assets'].find { |a| a['id'] == 'letter_home' }['text']
    assert_equal 'Ada', catalog['assets'].find { |a| a['id'] == 'book_old_map' }['author']
    assert_equal 'new_role', catalog['assets'].find { |a| a['id'] == 'new_line' }['speaker']
    path = File.join(@root, 'assets/imported/catalog.json')
    before = File.mtime(path)
    assert_equal catalog, importer.build
    assert_equal before, File.mtime(path), 'An unchanged build must not trigger another Godot import'
    pack('future_pack')
    assert_equal 2, importer.build['assets'].count { |a| a['kind'] == 'model' }
    write('lore/content/next.json', JSON.generate({id: 'next_note', kind: 'lore', title: 'Next Note', text: 'A new place.'}))
    assert importer.build['assets'].any? { |a| a['id'] == 'next_note' }
    @config['rules'][0]['exclude'] = ['**/model.gltf']
    assert_equal 0, importer.build['assets'].count { |a| a['kind'] == 'model' }
    refute File.exist?(File.join(@root, 'assets/imported/packs/new_pack/models/model.gltf'))
  end

  def test_invalid_content_preserves_previous_output
    pack('safe')
    importer = AssetImporter.new(@root, @config)
    importer.build
    previous = File.binread(File.join(@root, 'assets/imported/catalog.json'))
    pack('bad', '../../../../outside.bin')
    assert_raises(AssetImporter::Error) { importer.build }
    assert_equal previous, File.binread(File.join(@root, 'assets/imported/catalog.json'))
    FileUtils.rm_rf(File.join(@root, 'import_assets/free_packs/bad'))
    FileUtils.rm(File.join(@root, 'import_assets/free_packs/safe/LICENSE.txt'))
    assert_raises(AssetImporter::Error) { importer.build }
    assert_equal previous, File.binread(File.join(@root, 'assets/imported/catalog.json'))
    write('import_assets/free_packs/safe/LICENSE.txt', 'Fixture license notice')
    write('lore/content/duplicate.json', JSON.generate({id: 'safe/models/model.gltf', kind: 'lore', text: 'Duplicate.'}))
    assert_raises(AssetImporter::Error) { importer.build }
    FileUtils.rm(File.join(@root, 'lore/content/duplicate.json'))
    write('lore/content/unlicensed.json', JSON.generate({id: 'external', kind: 'lore', text: 'External text.', license: 'CC-BY-4.0', author: 'Creator', source: 'https://example.org', license_url: 'https://creativecommons.org/licenses/by/4.0/'}))
    assert_raises(AssetImporter::Error) { importer.build }
    assert_equal previous, File.binread(File.join(@root, 'assets/imported/catalog.json'))
  end

  def test_rebuild_invalidates_model_cache_with_extracted_textures
    pack('embedded')
    importer = AssetImporter.new(@root, @config)
    importer.build
    relative = 'assets/imported/packs/embedded/models/model.gltf'
    write(relative + '.import', 'Cached scene referring to an extracted texture')
    write(relative + '.uid', 'Keep stable UID')
    write('assets/imported/packs/embedded/models/model_Atlas.png', 'Godot extracted texture')
    importer.build
    assert File.file?(File.join(@root, relative + '.import')), 'An unchanged build must preserve existing cache metadata'
    write('lore/content/new.json', JSON.generate({id: 'new_note', kind: 'lore', text: 'New content.'}))
    importer.build
    assert File.file?(File.join(@root, relative + '.import')), 'Lore-only changes must preserve unchanged model cache metadata'
    assert File.file?(File.join(@root, 'assets/imported/packs/embedded/models/model_Atlas.png')), 'Lore-only changes must retain Godot extracted textures'
    assert_equal 'Keep stable UID', File.read(File.join(@root, relative + '.uid'))
    model_source = File.join(@root, 'import_assets/free_packs/embedded/models/model.gltf')
    File.write(model_source, File.read(model_source) + "\n")
    importer.build
    refute File.file?(File.join(@root, relative + '.import')), 'A rebuilt model must be reimported when extracted textures are discarded'
  end

  def test_glb_external_images_and_symlink_escape
    pack('glb_pack')
    FileUtils.rm(File.join(@root, 'import_assets/free_packs/glb_pack/models/model.gltf'))
    json = JSON.generate({asset: {version: '2.0'}, images: [{uri: '../textures/color.png'}]})
    json += ' ' * ((4 - json.bytesize % 4) % 4)
    write('import_assets/free_packs/glb_pack/models/model.glb', ['glTF', 2, 20 + json.bytesize, json.bytesize, 'JSON'].pack('a4V3a4') + json)
    importer = AssetImporter.new(@root, @config)
    importer.build
    assert File.file?(File.join(@root, 'assets/imported/packs/glb_pack/textures/color.png'))
    FileUtils.rm(File.join(@root, 'import_assets/free_packs/glb_pack/textures/color.png'))
    File.symlink('/etc/hosts', File.join(@root, 'import_assets/free_packs/glb_pack/textures/color.png'))
    assert_raises(AssetImporter::Error) { importer.build }
  end
end
