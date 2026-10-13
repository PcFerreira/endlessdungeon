require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'
require_relative '../tools/build_lore'

class LoreExportTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('lore-export-test-')
    write('lore/books.md', "## A Road Note\n\nBook ID: `book_note`. Author: a traveler. Placement: shelf.\n\n> Come home.\n")
    @entries = [
      {id: 'keeper_arrival', kind: 'dialogue', speaker: 'fountain_keeper', event: 'greeting', condition: 'Any', variant_group: 'keeper_arrival', text_key: 'lore.keeper_arrival.text', source_locale: 'en', text: 'Welcome to {city_name}.'},
      {id: 'keeper_arrival_v02', kind: 'dialogue', speaker: 'fountain_keeper', event: 'greeting', condition: 'Any', variant_group: 'keeper_arrival', text_key: 'lore.keeper_arrival_v02.text', source_locale: 'en', text: 'Rest in {city_name}.'},
      {id: 'quest_note', kind: 'local_quest', title: 'A Request', text: 'Visit {dungeon_name}.', choices: [{id: 'same', label: 'They agree.'}], target: {kind: 'ruin_archive', label: 'Old inscription'}},
      {id: 'history_note', kind: 'regional_history', title: 'The Account', text: 'A road.', event_notes: [{kind: 'supper', phase: 'aftermath', text: 'Cups washed.'}]}
    ]
    write('lore/content/entries.json', JSON.generate(@entries))
    @exporter = LoreExporter.new(@root)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def write(path, text)
    destination = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(destination))
    File.write(destination, text)
  end

  def read(path)
    JSON.parse(File.read(File.join(@root, path)))
  end

  def test_export_preserves_content_and_keys_across_source_reordering
    @exporter.build
    english = read('lore/locales/en.json')
    assert_equal 'Welcome to {city_name}.', english['messages']['lore.keeper_arrival.text']
    assert_equal 'They agree.', english['messages']['lore.quest_note.choices.same.label']
    assert_equal 'Old inscription', english['messages']['lore.quest_note.target.label']
    assert_equal 'Cups washed.', english['messages']['lore.history_note.event_notes.supper.aftermath.text']
    assert_equal 'Come home.', english['messages']['lore.book_note.text']
    refute english['messages'].keys.any? { |key| key.include?('condition') || key.include?('variant_group') }
    assert_equal 'keeper_arrival', read('assets/lore/catalog.json')['lines'][1]['variant_group']
    write('lore/content/entries.json', JSON.generate(@entries.reverse))
    @exporter.build
    assert_equal english, read('lore/locales/en.json')
  end

  def test_partial_translation_and_exact_placeholder_validation
    @exporter.build
    template = @exporter.locale_template('pt-BR')
    assert template['messages'].values.all?(&:empty?)
    template['messages'] = {'lore.keeper_arrival.text' => 'Boas-vindas a {city_name}.'}
    write('lore/locales/pt-BR.json', JSON.generate(template))
    @exporter.build
    assert_equal template, read('assets/lore/locales/pt-BR.json')
    template['messages']['lore.keeper_arrival.text'] = 'Boas-vindas a {town}.'
    write('lore/locales/pt-BR.json', JSON.generate(template))
    assert_raises(LoreExporter::Error) { @exporter.build }
    template['messages'] = {'lore.unknown.text' => 'Uma estrada.'}
    write('lore/locales/pt-BR.json', JSON.generate(template))
    assert_raises(LoreExporter::Error) { @exporter.build }
  end

  def test_check_detects_stale_english_without_overwriting_a_translation
    @exporter.build
    assert @exporter.build(check: true)
    @entries[0][:text] = 'A cup waits in {city_name}.'
    write('lore/content/entries.json', JSON.generate(@entries))
    assert_raises(LoreExporter::Error) { @exporter.build(check: true) }
  end

  def test_source_changes_require_review_of_a_filled_translation
    @exporter.build
    template = @exporter.locale_template('pt-BR')
    template['messages'] = {'lore.keeper_arrival.text' => 'Boas-vindas a {city_name}.'}
    write('lore/locales/pt-BR.json', JSON.generate(template))
    @entries[0][:text] = 'Welcome home to {city_name}.'
    write('lore/content/entries.json', JSON.generate(@entries))
    assert_raises(LoreExporter::Error) { @exporter.build }
  end

  def test_gameplay_name_keys_follow_content_ids_and_keep_source_context
    write('config/player_text.json', JSON.generate({version: 1, names: {items: {'item:atlas/blue-weapon' => 'Weapon'}, native: {'wall_shelf' => 'Wall Shelf'}, fallbacks: {'object' => 'Object'}}}))
    write('config/town_architecture.json', JSON.generate({version: 1, templates: {'hex_castle' => {name: 'Town Keep'}}}))
    @exporter.build
    english = read('lore/locales/en.json')['messages']
    assert_equal 'Weapon', english['gameplay.items.item:atlas/blue-weapon.name']
    assert_equal 'Town Keep', english['gameplay.architecture.hex_castle.name']
    assert_equal 'Wall Shelf', english['gameplay.native.wall_shelf.name']
    context = read('lore/locales/context.json')['messages']['gameplay.architecture.hex_castle.name']
    assert_equal 'config/town_architecture.json', context['source_file']
    assert_equal 'hex_castle', context['target_id']
  end
end
