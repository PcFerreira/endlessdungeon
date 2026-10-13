require 'json'
require 'zlib'

module ContentGeometry
  # Slab6 stores x/y/z indexed cells followed by a 6-bit RGB palette.
  # MagicaVoxel stores explicit cells in XYZI and an optional RGBA palette.
  def self.voxels(path)
    bytes = File.binread(path)
    cells = {}
    if bytes.start_with?('VOX ')
      offset, palettes, models = 8, nil, []
      while offset + 12 <= bytes.size
        kind, size, = bytes.byteslice(offset, 12).unpack('a4V2')
        content = bytes.byteslice(offset + 12, size)
        raise 'Truncated VOX chunk' unless content && content.size == size
        models << content.byteslice(4..-1).unpack('C*').each_slice(4).to_a if kind == 'XYZI'
        palettes = content.unpack('C*').each_slice(4).to_a if kind == 'RGBA'
        offset += 12 + size
      end
      raise 'VOX needs one static model and an explicit palette' unless models.size == 1 && palettes && palettes.size == 256
      models.first.each { |x,y,z,c| cells[[x,y,z]] = palettes.fetch(c - 1).first(3) }
    else
      x_size, y_size, z_size = bytes.unpack('V3')
      count = x_size * y_size * z_size
      raise 'Invalid Slab6 voxel dimensions' unless count > 0 && count <= 2000000 && bytes.size == 12 + count + 768
      palette = bytes.byteslice(-768, 768).unpack('C*').each_slice(3).map { |rgb| rgb.map { |c| [c * 4, 255].min } }
      bytes.byteslice(12, count).unpack('C*').each_with_index do |color, index|
        next if color == 255
        x = index / (y_size * z_size)
        y, z = (index / z_size) % y_size, index % z_size
        # Slab6 cells are stored top to bottom on Z.
        cells[[x,y,z_size - 1 - z]] = palette.fetch(color)
      end
    end
    raise 'Empty voxel source' if cells.empty?
    cells
  end

  FACES = [
    [[1,0,0], [[1,0,0],[1,1,0],[1,1,1],[1,0,1]]],
    [[-1,0,0], [[0,0,1],[0,1,1],[0,1,0],[0,0,0]]],
    [[0,1,0], [[0,1,0],[0,1,1],[1,1,1],[1,1,0]]],
    [[0,-1,0], [[0,0,1],[0,0,0],[1,0,0],[1,0,1]]],
    [[0,0,1], [[0,0,1],[1,0,1],[1,1,1],[0,1,1]]],
    [[0,0,-1], [[0,1,0],[1,1,0],[1,0,0],[0,0,0]]]
  ].freeze

  def self.linear(value)
    value /= 255.0
    value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4
  end

  def self.voxel_glb(source, destination)
    cells = voxels(source)
    positions, normals, colors = [], [], []
    cells.each do |point, rgb|
      FACES.each do |normal, corners|
        next if cells.key?(point.zip(normal).map { |a,b| a+b })
        # x,z,-y has positive determinant and keeps glTF's CCW winding.
        [0,1,2,0,2,3].each do |index|
          x,y,z = point.zip(corners[index]).map { |a,b| (a+b) * 0.02 }
          positions.concat([x,z,-y])
          normals.concat([normal[0],normal[2],-normal[1]])
          colors.concat(rgb.map { |v| linear(v) })
        end
      end
    end
    arrays = [positions,normals,colors]
    binary = arrays.map { |a| a.pack('e*') }.join
    cursor = 0
    views = arrays.map { |a| view = {buffer:0,byteOffset:cursor,byteLength:a.size*4,target:34962}; cursor += a.size*4; view }
    points = positions.each_slice(3).to_a
    accessors = arrays.each_index.map { |i| {bufferView:i,componentType:5126,count:positions.size/3,type:'VEC3'} }
    accessors[0][:min] = (0..2).map { |i| points.map { |p| p[i] }.min }
    accessors[0][:max] = (0..2).map { |i| points.map { |p| p[i] }.max }
    document = {asset:{version:'2.0',generator:'Endless Dungeon source-preserving voxel converter'},scene:0,scenes:[{nodes:[0]}],nodes:[{mesh:0}],meshes:[{primitives:[{attributes:{POSITION:0,NORMAL:1,COLOR_0:2},material:0}]}],materials:[{pbrMetallicRoughness:{metallicFactor:0,roughnessFactor:1}}],buffers:[{byteLength:binary.size}],bufferViews:views,accessors:accessors}
    json = JSON.generate(document)
    json += ' ' * ((4-json.size%4)%4)
    binary += "\0" * ((4-binary.size%4)%4)
    File.binwrite(destination, ['glTF',2,12+8+json.size+8+binary.size].pack('a4V2') + [json.size,'JSON'].pack('Va4') + json + [binary.size,'BIN'].pack('Va4') + binary)
  end

  def self.png_pixels(path)
    bytes = File.binread(path)
    raise 'Invalid PNG signature' unless bytes.start_with?("\x89PNG\r\n\x1a\n".b)
    offset, compressed, width, height, channels = 8, ''.b, nil, nil, nil
    while offset + 12 <= bytes.size
      size = bytes.byteslice(offset,4).unpack1('N')
      kind, data = bytes.byteslice(offset+4,4), bytes.byteslice(offset+8,size)
      if kind == 'IHDR'
        width,height,depth,type,_,_,interlace = data.unpack('N2C5')
        raise 'Atlas PNG must be noninterlaced 8-bit RGBA' unless depth == 8 && type == 6 && interlace == 0
        channels = 4
      end
      compressed += data if kind == 'IDAT'
      offset += size + 12
    end
    raw, previous, rows = Zlib::Inflate.inflate(compressed), Array.new(width*channels,0), []
    height.times do |y|
      start = y*(width*channels+1)
      filter = raw.getbyte(start)
      line = raw.byteslice(start+1,width*channels).unpack('C*')
      line.each_index do |x|
        left, up, corner = x >= channels ? line[x-channels] : 0, previous[x], x >= channels ? previous[x-channels] : 0
        predictor = case filter
        when 0 then 0
        when 1 then left
        when 2 then up
        when 3 then (left+up)/2
        when 4
          p = left+up-corner
          distances = [(p-left).abs,(p-up).abs,(p-corner).abs]
          [left,up,corner][distances.index(distances.min)]
        else raise 'Invalid PNG filter'
        end
        line[x] = (line[x]+predictor)&255
      end
      rows << line
      previous = line
    end
    [width,height,rows]
  end

  def self.atlas_regions(path, cell)
    width,height,rows = png_pixels(path)
    result = []
    (0...height).step(cell) do |y|
      (0...width).step(cell) do |x|
        next if x+cell > width || y+cell > height
        occupied = (y...y+cell).any? { |py| (x...x+cell).any? { |px| rows[py][px*4+3] > 0 } }
        result << [x,y,cell,cell] if occupied
      end
    end
    result
  end
end
