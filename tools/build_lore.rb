require 'json'
require 'fileutils'
require 'optparse'
require 'digest'
require_relative 'import_assets'

class LoreExporter
  class Error < StandardError; end
  FIELDS = %w[title author text marker_label ledger_prompt inscription finding completion landmark_text book_text witness_text].freeze
  SOURCES = [{ 'glob' => 'lore/**/*.md', 'format' => 'markdown' }, { 'glob' => 'lore/content/**/*.json', 'format' => 'entries' }].freeze

  def initialize(root)
    @root = File.expand_path(root)
  end

  def locale_name(value)
    raise Error, "Invalid locale: #{value.inspect}" unless value.is_a?(String) && value.match?(/\A[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/)
    value
  end

  def placeholders(text)
    raise Error, 'Messages must be strings' unless text.is_a?(String)
    remainder = text.gsub(/\{[a-z][a-z0-9_]*\}/, '')
    raise Error, "Invalid message braces: #{text}" if remainder.include?('{') || remainder.include?('}')
    text.scan(/\{[a-z][a-z0-9_]*\}/).uniq.sort
  end

  def collect
    entries = AssetImporter.new(@root, {'lore_sources' => SOURCES}).lore_entries.sort_by { |entry| entry.fetch('id') }
    raise Error, 'Duplicate lore ID' unless entries.map { |entry| entry['id'] }.uniq.size == entries.size
    messages, context = {}, {}
    entries.each do |entry|
      FIELDS.each do |field|
        next unless entry[field].is_a?(String)
        key = field == 'text' ? entry.fetch('text_key', "lore.#{entry['id']}.text") : "lore.#{entry['id']}.#{field}"
        add_message(messages, context, key, entry[field], entry)
      end
      entry.fetch('choices', []).each do |choice|
        add_message(messages, context, "lore.#{entry['id']}.choices.#{choice.fetch('id')}.label", choice.fetch('label'), entry)
      end
      if entry.fetch('target', {}).key?('label')
        add_message(messages, context, "lore.#{entry['id']}.target.label", entry['target']['label'], entry)
      end
      entry.fetch('event_notes', []).each do |note|
        key = "lore.#{entry['id']}.event_notes.#{note.fetch('kind')}.#{note.fetch('phase')}.text"
        add_message(messages, context, key, note.fetch('text'), entry)
      end
    end
    player_path = File.join(@root, 'config/player_text.json')
    if File.file?(player_path)
      player = JSON.parse(File.read(player_path))
      raise Error, 'Invalid gameplay name catalogue' unless player.is_a?(Hash) && player['version'] == 1 && player['names'].is_a?(Hash)
      add_names(messages, context, player['names'], 'config/player_text.json')
    end
    architecture_path = File.join(@root, 'config/town_architecture.json')
    if File.file?(architecture_path)
      architecture = JSON.parse(File.read(architecture_path))
      raise Error, 'Invalid architecture name catalogue' unless architecture.is_a?(Hash) && architecture['templates'].is_a?(Hash)
      names = architecture['templates'].transform_values { |template| template.fetch('name') }
      add_names(messages, context, {'architecture' => names}, 'config/town_architecture.json')
    end
    [entries, messages.sort.to_h, context.sort.to_h]
  rescue AssetImporter::Error, KeyError, JSON::ParserError => e
    raise Error, e.message
  end

  def add_names(messages, context, groups, source)
    groups.each do |group, names|
      raise Error, "Invalid gameplay name group: #{group}" unless names.is_a?(Hash)
      names.each do |id, name|
        prefix = "gameplay.#{group}.#{id}."
        entry = {'id' => id, 'target_id' => id, 'content_type' => 'gameplay_name', 'source_file' => source}
        add_message(messages, context, prefix + 'name', name, entry, prefix)
      end
    end
  end

  def add_message(messages, context, key, text, entry, prefix = nil)
    raise Error, "Duplicate translation key: #{key}" if messages.key?(key)
    prefix ||= "lore.#{entry['id']}."
    raise Error, "Invalid translation key: #{key.inspect}" unless key.is_a?(String) && key.start_with?(prefix)
    messages[key] = text
    context[key] = entry.slice('source_file', 'content_type', 'speaker', 'event', 'condition', 'variant_group', 'variant', 'target_id').merge('placeholders' => placeholders(text), 'source_sha256' => Digest::SHA256.hexdigest(text))
  end

  def locale_template(locale)
    locale_name(locale)
    raise Error, 'English is generated from authored source records' if locale == 'en'
    _, messages, = collect
    {'version' => 1, 'source_locale' => 'en', 'locale' => locale, 'messages' => messages.transform_values { '' }, 'source_hashes' => messages.transform_values { |text| Digest::SHA256.hexdigest(text) }}
  end

  def translations(messages)
    Dir.glob(File.join(@root, 'lore/locales/*.json')).sort.each_with_object({}) do |path, result|
      next if %w[en.json context.json].include?(File.basename(path))
      locale = locale_name(File.basename(path, '.json'))
      document = JSON.parse(File.read(path))
      unless document.is_a?(Hash) && document['version'] == 1 && document['source_locale'] == 'en' && document['locale'] == locale && document['messages'].is_a?(Hash) && document['source_hashes'].is_a?(Hash)
        raise Error, "Invalid locale document: #{path}"
      end
      document['messages'].each do |key, text|
        raise Error, "Unknown translation key in #{locale}: #{key}" unless messages.key?(key)
        raise Error, "Non-string translation in #{locale}: #{key}" unless text.is_a?(String)
        next if text.empty?
        raise Error, "Changed placeholders in #{locale}: #{key}" unless placeholders(text) == placeholders(messages[key])
        raise Error, "English source changed in #{locale}: #{key}. Review the translation and its source hash." unless document['source_hashes'][key] == Digest::SHA256.hexdigest(messages[key])
      end
      result[locale] = document
    end
  rescue JSON::ParserError => e
    raise Error, e.message
  end

  def build(check: false)
    entries, messages, context = collect
    localized = translations(messages)
    books = entries.select { |entry| entry['content_type'] == 'book' }.to_h do |entry|
      [entry.fetch('id'), entry.slice('title', 'author', 'text').merge('text_key' => "lore.#{entry['id']}.text")]
    end
    lines = entries.select { |entry| entry['content_type'] == 'dialogue' }.map do |entry|
      entry.slice('id', 'speaker', 'event', 'condition', 'text', 'biomes', 'life_kind', 'life_phase', 'weight', 'variant_group', 'variant', 'text_key', 'source_locale')
    end
    english = {'version' => 1, 'source_locale' => 'en', 'locale' => 'en', 'messages' => messages}
    outputs = {
      'assets/lore/catalog.json' => {'version' => 2, 'books' => books, 'lines' => lines},
      'lore/locales/en.json' => english,
      'lore/locales/context.json' => {'version' => 1, 'messages' => context},
      'assets/lore/locales/en.json' => english,
      'assets/lore/locales/manifest.json' => {'version' => 1, 'source_locale' => 'en', 'locales' => ['en'] + localized.keys, 'message_count' => messages.size}
    }
    localized.each { |locale, document| outputs["assets/lore/locales/#{locale}.json"] = document }
    outputs.each do |relative, document|
      text = JSON.pretty_generate(document) + "\n"
      destination = File.join(@root, relative)
      if check
        raise Error, "Lore export is out of date: #{relative}. Run ruby tools/build_lore.rb." unless File.file?(destination) && File.read(destination) == text
      else
        FileUtils.mkdir_p(File.dirname(destination))
        File.write(destination, text) unless File.file?(destination) && File.read(destination) == text
      end
    end
    {books: books.size, lines: lines.size, messages: messages.size, locales: 1 + localized.size}
  end
end

if $PROGRAM_NAME == __FILE__
  options = {root: File.expand_path('..', __dir__), check: false}
  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: ruby tools/build_lore.rb [--check | --locale-template LOCALE] [--root PATH]'
    opts.on('--check') { options[:check] = true }
    opts.on('--locale-template LOCALE') { |locale| options[:locale] = locale }
    opts.on('--root PATH') { |path| options[:root] = path }
  end
  begin
    parser.parse!
    raise LoreExporter::Error, 'Choose either --check or --locale-template' if options[:check] && options[:locale]
    exporter = LoreExporter.new(options[:root])
    if options[:locale]
      puts JSON.pretty_generate(exporter.locale_template(options[:locale]))
    else
      result = exporter.build(check: options[:check])
      puts "PASS: #{result[:books]} book editions, #{result[:lines]} authored dialogue lines, #{result[:messages]} translation keys, #{result[:locales]} locale packs"
    end
  rescue LoreExporter::Error, OptionParser::ParseError, Errno::ENOENT => e
    warn e.message
    exit 1
  end
end
