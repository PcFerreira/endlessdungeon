require 'minitest/autorun'
require_relative '../tools/build_content_bundles'

class ContentBundlesTest < Minitest::Test
  def test_new_assets_are_selected_and_ids_are_stable
    Dir.mktmpdir do |root|
      pack = File.join(root,'import_assets/test')
      FileUtils.mkdir_p(pack)
      File.write(File.join(pack,'SOURCE.json'),JSON.generate({id:'test',title:'Test',author:'Test',source:'workspace://test',license:'CC0',license_url:'workspace://test'}))
      File.write(File.join(pack,'LICENSE.txt'),'Test fixture')
      config = { 'version'=>1,'rules'=>[{'pack'=>'test','include'=>['*.glb'],'role'=>'enemy'}], 'defaults'=>{'enemy'=>{'hp'=>1}},'profiles'=>{},'conversions'=>[] }
      File.write(File.join(pack,'one.glb'),'fixture')
      builder = ContentBundles.new(root,config)
      first = builder.build['enemies'].first['id']
      File.write(File.join(pack,'two.glb'),'fixture-two')
      result = ContentBundles.new(root,config).build
      assert_equal 2,result['enemies'].size
      assert_includes result['enemies'].map { |e| e['id'] },first
      File.write(File.join(pack,'three.glb'),'fixture-three')
      assert_raises(RuntimeError) { ContentBundles.new(root,config).build(check:true) }
    end
  end

  def test_voxel_conversion_culls_hidden_faces_and_preserves_color
    Dir.mktmpdir do |root|
      # Two adjoining colored cells in the legacy Slab6 format.
      source,target = File.join(root,'test.vox'),File.join(root,'test.glb')
      palette = Array.new(768,0); palette[3,3] = [63,32,0]
      File.binwrite(source,[2,1,1].pack('V3')+[1,1].pack('C*')+palette.pack('C*'))
      ContentGeometry.voxel_glb(source,target)
      document = AssetImporter.new(root,{}).gltf_document(target)
      assert_equal 60,document['accessors'][0]['count'], '10 exposed faces, 6 vertices each'
      assert_equal [0.04,0.02,0.0],document['accessors'][0]['max']
      assert_equal 1,document['meshes'].size
      bytes = File.binread(target)
      json_size = bytes.byteslice(12,4).unpack1('V')
      color_offset = 20+json_size+8+document['bufferViews'][2]['byteOffset']
      color = bytes.byteslice(color_offset,12).unpack('e3')
      assert_in_delta 0.973445,color[0],0.00001
      assert_in_delta 0.215861,color[1],0.00001
      assert_equal 0,color[2]
      File.binwrite(source,'bad')
      assert_raises(StandardError) { ContentGeometry.voxels(source) }
    end
  end
end
