require_relative 'import_assets'
require_relative 'content_geometry'
require 'open3'

class ContentBundles
  CONVERTER_VERSION = 4
  EXTENSIONS = %w[.gltf .glb .obj .fbx .vox .blend .qb .png .svg .jpg .jpeg .ogg .wav .mp3 .bin .mtl .tscn .tres].freeze
  attr_reader :catalog, :inventory, :imports

  def initialize(root, config = nil)
    @root = File.realpath(root)
    @config = config || JSON.parse(File.read(File.join(@root,'config/content_bundles.json')))
    raise 'Invalid content bundles configuration' unless @config['version'] == 1 && @config['rules'].is_a?(Array)
    @packs = {}
    Dir.glob(File.join(@root,'import_assets/**/SOURCE.json')).sort.each do |path|
      source = JSON.parse(File.read(path))
      @packs[source.fetch('id')] = {source:source, directory:File.dirname(path)}
    end
  end

  def write_json(path, value, check: false)
    text = JSON.pretty_generate(value) + "\n"
    return if File.file?(path) && File.read(path) == text
    raise "Stale bundle output: #{path}; run ruby tools/build_content_bundles.rb" if check
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path + '.tmp',text)
    File.rename(path + '.tmp',path)
  end

  def slug(value)
    value.gsub(/[^a-zA-Z0-9_-]+/,'-').sub(/^-+/,'').sub(/-+$/,'').downcase
  end

  def convert(check: false, blender: nil)
    @derived = {}
    @config.fetch('conversions',[]).each do |rule|
      pack = @packs.fetch(rule.fetch('pack'))
      directory = File.join(@root,'import_assets/bundled',rule['pack'])
      manifest_path = File.join(directory,'CONVERSIONS.json')
      previous = File.file?(manifest_path) ? JSON.parse(File.read(manifest_path))['records'] : []
      records = []
      Dir.glob(File.join(pack[:directory],rule['include'])).sort.each do |path|
        relative = path.delete_prefix(@root+'/')
        digest = Digest::SHA256.file(path).hexdigest
        cached = previous.select { |record| record['source_file'] == relative }
        fresh = !cached.empty? && cached.all? { |r| r['converter_version'] == CONVERTER_VERSION && r['source_sha256'] == digest && File.file?(File.join(directory,r['runtime_file'])) && Digest::SHA256.file(File.join(directory,r['runtime_file'])).hexdigest == r['sha256'] }
        if fresh
          records.concat(cached)
          next
        end
        raise "Conversion is stale: #{relative}" if check
        FileUtils.mkdir_p(directory)
        if rule['format'] == 'vox'
          name = File.basename(path,File.extname(path))
          file = slug(name)+'.glb'
          ContentGeometry.voxel_glb(path,File.join(directory,file))
          exports = [{'name'=>name,'object'=>name,'file'=>File.join(directory,file)}]
        else
          raise "Blender is needed to convert #{relative}; pass --blender PATH" unless blender && File.executable?(blender)
          Dir.mktmpdir('endless-content-conversion') do |temp|
            request = {manifest:File.join(temp,'result.json'),jobs:[{source:path,relative:relative,target:directory,split:rule['format']=='blend_objects'}]}
            File.write(File.join(temp,'request.json'),JSON.generate(request))
            log, status = Open3.capture2e(blender,'--background','--python-exit-code','1','--python',File.join(@root,'tools/convert_content.py'),'--',File.join(temp,'request.json'))
            raise "Blender conversion failed: #{relative}\n#{log.lines.last(15).join}" unless status.success?
            exports = JSON.parse(File.read(request[:manifest]))['records']
          end
        end
        exports.each do |export|
          records << {'source_file'=>relative,'source_sha256'=>digest,'object'=>export['object'],'name'=>export['name'],'runtime_file'=>File.basename(export['file']),'sha256'=>Digest::SHA256.file(export['file']).hexdigest,'converter_version'=>CONVERTER_VERSION}
        end
      end
      raise "Conversion selector has no assets: #{rule['pack']}" if records.empty?
      extras = Dir.glob(File.join(directory,'*.glb')).reject { |path| records.any? { |r| r['runtime_file']==File.basename(path) } }
      raise "Stale converted models: #{extras.join(', ')}" if check && !extras.empty?
      extras.each { |path| FileUtils.rm(path) } unless check
      source = pack[:source].dup.merge('id'=>'bundle_'+rule['pack'],'title'=>pack[:source]['title']+' / game-ready conversions','source_asset_changes'=>'Derived GLB exports. Original file and per-object identities and hashes are retained in CONVERSIONS.json.')
      write_json(File.join(directory,'SOURCE.json'),source,check:check)
      write_json(manifest_path,{'version'=>1,'records'=>records},check:check)
      notices = Dir.glob(File.join(pack[:directory],'**/*')).select { |p| File.file?(p) && File.basename(p).match?(AssetImporter::NOTICE) && ['', '.txt','.md','.html'].include?(File.extname(p).downcase) }
      notices.each do |path|
        target = File.join(directory,'notices',path.delete_prefix(pack[:directory]+'/'))
        if check
          raise "Missing conversion notice: #{target}" unless File.file?(target) && File.binread(target) == File.binread(path)
        else
          FileUtils.mkdir_p(File.dirname(target)); FileUtils.cp(path,target)
        end
      end
      @packs[source['id']] = {source:source,directory:directory}
      records.each { |r| @derived[source['id']+'/'+r['runtime_file']] = r }
    end
  end

  def match(rule, asset)
    return false unless File.fnmatch?(rule.fetch('pack','*'),asset['pack'])
    flags = File::FNM_PATHNAME | File::FNM_EXTGLOB
    rule.fetch('include',['**/*']).any? { |pattern| File.fnmatch?(pattern,asset['relative'],flags) } && !rule.fetch('exclude',[]).any? { |pattern| File.fnmatch?(pattern,asset['relative'],flags) }
  end

  def logical(asset, rule)
    relative = asset['relative']
    if rule['group_views']
      relative.sub(/_[ENWS]\.[^.]+$/, '')
    elsif rule['group_resolutions']
      parts = relative.split('/')
      [parts.first,parts[1].sub(/-scalable$/,''),File.basename(relative,File.extname(relative))].join('/')
    else
      relative.sub(/\.[^.]+$/,'')
    end
  end

  def title(asset)
    name = @derived.fetch(asset['id'],{}).fetch('name',asset['title'])
    name = name.sub(/^SM_VMF_/,'').sub(/^animals-\d+-/,'').sub(/^[A-Z]_/,'')
    name.gsub(/([a-z])([A-Z])/,'\1 \2').gsub(/[_-]+/,' ').split.map { |word| word.capitalize }.join(' ')
  end

  def entry(asset, rule, region = nil)
    role = rule['role']
    definition = Marshal.load(Marshal.dump(@config['defaults'].fetch(role)))
    key = logical(asset,rule)+(region ? '/cell-'+region.first(2).join('-') : '')
    identity = role+':'+asset['pack']+'/'+slug(key)[0,65]+'-'+Digest::SHA256.hexdigest(key)[0,10]
    definition.merge!('id'=>identity,'name'=>title(asset),'source_asset'=>asset['id'],'source_pack'=>asset['pack'])
    definition['name'] += ' %s-%s' % region.first(2).map { |n| n/rule['atlas_cell']+1 } if region
    if region && rule['atlas_labels']
      width = File.binread(File.join(@root,asset['source_file']),24).byteslice(16,4).unpack1('N')
      definition['name'] = rule['atlas_labels'].fetch(region[1]/rule['atlas_cell']*(width/rule['atlas_cell'])+region[0]/rule['atlas_cell'])
    end
    if role == 'item' && rule['kind']
      definition['kind'] = rule['kind']
      if rule['kind'] == 'furnishing'
        definition.merge!('stack'=>10,'description'=>'A furnishing collected for your sanctum.','icon'=>'res://assets/items/oak_chair.svg')
      elsif rule['kind'] == 'consumable'
        definition.merge!('stack'=>20,'restore_health'=>20,'description'=>'Consume to restore 20 vitality when needed.','icon'=>'res://assets/items/health_potion.svg')
      end
    end
    @config['profiles'].fetch(role,[]).each do |profile|
      next if profile['pack'] && profile['pack'] != asset['pack']
      definition.merge!(profile['set']) if Regexp.new(profile['match']).match?(title(asset))
    end
    if role == 'enemy'
      definition['visual'] = {'tags'=>[],'pack'=>asset['pack'],'patterns'=>[asset['id']]}
      definition['sprite'] = rule['sprite'].merge('asset_id'=>asset['id']) if rule['sprite']
    elsif role == 'animal'
      definition['models'] = {'tags'=>[],'pack'=>asset['pack'],'patterns'=>[asset['id']]}
    else
      definition['loot_sources'] = @config.fetch('loot_sources', {}).fetch(definition['kind'], ['enemy','chest'])
      if asset['kind'] == 'model'
        definition['asset_id'] = asset['id']
        if rule['icon_template']
          icon = rule['icon_template'].gsub('{stem}',File.basename(asset['relative'],File.extname(asset['relative'])))
          definition['icon'] = "res://assets/imported/packs/#{asset['pack']}/#{icon}"
          @selected[asset['pack']+'/'+icon] = ['item-icon']
        end
      else
        definition['icon'] = "res://assets/imported/packs/#{asset['pack']}/#{asset['relative']}"
        definition['icon_region'] = region if region
      end
    end
    definition
  end

  def build(check: false, blender: nil)
    convert(check:check,blender:blender)
    scan = AssetImporter.new(@root,{'version'=>1,'rules'=>[]}).scan
    @selected, definitions = {}, {'enemy'=>[],'animal'=>[],'item'=>[]}
    @config['rules'].each do |rule|
      assets = scan['assets'].select { |asset| match(rule,asset) }
      raise "Bundle rule matched nothing: #{rule.inspect}" if assets.empty?
      groups = assets.group_by { |asset| logical(asset,rule) }
      groups.sort.each do |_, candidates|
        asset = candidates.max_by { |a| [File.extname(a['relative'])=='.svg' ? 64 : (a['relative'].include?('/32x32/') ? 32 : 1), a['id']] }
        candidates.each { |a| (@selected[a['id']] ||= []) << (a==asset ? rule['role'] : 'alternate') }
        regions = rule['atlas_cell'] ? ContentGeometry.atlas_regions(File.join(@root,asset['source_file']),rule['atlas_cell']) : [nil]
        regions.each { |region| definitions.fetch(rule['role']) << entry(asset,rule,region) }
      end
    end
    definitions.each_value { |values| values.sort_by! { |v| v['id'] } }
    @catalog = {'version'=>1,'enemies'=>definitions['enemy'],'animals'=>definitions['animal'],'items'=>definitions['item']}
    # Exact IDs select geometry/icons; importer follows model dependencies and notices.
    rules = @selected.reject { |_,roles| roles==['alternate'] }.group_by { |id,_| id.split('/').first }.sort.map do |pack, selected|
      {'pack'=>pack,'include'=>selected.map { |id,_| id.delete_prefix(pack+'/') }.sort,'tags'=>['content-bundle']}
    end
    @imports = {'version'=>1,'rules'=>rules}
    by_path = scan['assets'].each_with_object({}) { |a,h| h[a['source_file']] = a }
    @inventory = {'version'=>1,'summary'=>definitions.transform_values(&:size),'packs'=>scan['packs'],'representations'=>[]}
    canonical = @catalog.values.grep(Array).flatten.group_by { |d| d['source_asset'] }
    Dir.glob(File.join(@root,'import_assets/**/*')).sort.each do |path|
      next unless File.file?(path) && EXTENSIONS.include?(File.extname(path).downcase)
      relative = path.delete_prefix(@root+'/')
      asset = by_path[relative]
      record = {'file'=>relative,'bytes'=>File.size(path),'sha256'=>Digest::SHA256.file(path).hexdigest,'status'=>'outside_creatures_items'}
      if asset
        record.merge!('asset_id'=>asset['id'],'pack'=>asset['pack'])
        roles = @selected.fetch(asset['id'],[])
        if canonical[asset['id']]
          record['status'] = 'gameplay'
          record['definitions'] = canonical[asset['id']].map { |d| d['id'] }
        elsif roles.include?('item-icon')
          record['status'] = 'item-icon'
        elsif roles.include?('alternate')
          record['status'] = 'alternate'
        elsif File.extname(path)=='.png' && asset['relative'].match?(/texture|colormap/i)
          record['status'] = 'support'
        end
        original = @derived[asset['id']]
        record['derived_from'] = original if original
      end
      source_models = @derived.values.select { |r| r['source_file'] == relative }
      unless source_models.empty?
        record['status'] = 'converted'
        record['runtime_assets'] = @derived.select { |_,r| r['source_file'] == relative }.keys.sort
      end
      # Other exports/resolutions of a selected logical model are catalogue alternates.
      if record['status']=='outside_creatures_items' && asset
        same_name = scan['assets'].any? { |a| [asset['pack'],'bundle_'+asset['pack']].include?(a['pack']) && a['title']==asset['title'] && canonical.key?(a['id']) }
        record['status']='alternate' if same_name
      end
      @inventory['representations'] << record
    end
    ids = definitions.values.flatten.map { |d| d['id'] }
    raise 'Duplicate gameplay content ID' unless ids.uniq.size == ids.size
    write_json(File.join(@root,'assets/bundles/catalog.json'),@catalog,check:check)
    write_json(File.join(@root,'assets/bundles/source_inventory.json'),@inventory,check:check)
    write_json(File.join(@root,'config/generated_content_imports.json'),@imports,check:check)
    @catalog
  end
end

if $PROGRAM_NAME == __FILE__
  options = {check:false,root:File.expand_path('..',__dir__)}
  OptionParser.new do |parser|
    parser.on('--check') { options[:check]=true }
    parser.on('--blender PATH') { |path| options[:blender]=File.expand_path(path) }
    parser.on('--root PATH') { |path| options[:root]=File.expand_path(path) }
  end.parse!
  begin
    builder = ContentBundles.new(options[:root])
    result = builder.build(check:options[:check],blender:options[:blender])
    puts "PASS: #{result['enemies'].size} enemy, #{result['animals'].size} animal and #{result['items'].size} item definitions; #{builder.inventory['representations'].size} staged representations catalogued"
  rescue StandardError => e
    warn "Content bundle failed: #{e.message}"
    exit 1
  end
end
