require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'json'

class NetworkManifestTest < Minitest::Test
  def test_dependencies_and_content_changes_require_a_new_revision
    require_relative '../tools/build_network_manifest'
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(["#{root}/scripts", "#{root}/config", "#{root}/assets"])
      File.write("#{root}/scripts/world.gd", "extends \"res://scripts/grid.gd\"\nconst DATA = \"res://assets/catalog.json\"\n")
      File.write("#{root}/scripts/grid.gd", 'extends RefCounted')
      File.write("#{root}/config/areas.json", '{"spacing":128}')
      File.write("#{root}/assets/catalog.json", '{"assets":[]}')
      builder = NetworkManifest.new(root, engine_version:'4.test', roots:['scripts/world.gd'])
      before = builder.document
      assert_equal %w[assets/catalog.json config/areas.json scripts/grid.gd scripts/world.gd], before.fetch('inputs').keys
      builder.write
      assert builder.fresh?
      File.write("#{root}/scripts/grid.gd", 'extends Resource')
      refute builder.fresh?
      refute_equal before.fetch('content_revision'), builder.document.fetch('content_revision')
      builder.write
      assert builder.fresh?
      assert_equal builder.document, JSON.parse(File.read("#{root}/config/network_manifest.json"))
      expanded = NetworkManifest.new(root, engine_version:'4.test', roots:['scripts/world.gd'], generator_version:6)
      assert_equal 6, expanded.document.fetch('generator_version')
      refute_equal builder.document.fetch('content_revision'), expanded.document.fetch('content_revision')
      expanded.write
      assert expanded.fresh?
      refute builder.fresh?
      assert_raises(NetworkManifest::Error) { NetworkManifest.new(root, engine_version:'4.test', roots:['scripts/world.gd'], generator_version:7) }
      FileUtils.mkdir_p("#{root}/server")
      File.write("#{root}/server/world_worker.gd", 'const World = preload("res://scripts/world.gd")')
      command = [RbConfig.ruby, File.expand_path('../tools/build_network_manifest.rb', __dir__), '--root', root, '--engine-version', '4.test']
      _, status = Open3.capture2e(*command, '--generator-version', '6')
      assert status.success?
      _, status = Open3.capture2e(*command, '--check')
      assert status.success?, 'CLI freshness must retain the published edition when no new edition is requested'
      _, status = Open3.capture2e(*command, '--check', '--generator-version', '4')
      refute status.success?, 'Different editions require different manifest revisions'
      File.write("#{root}/scripts/grid.gd", 'extends "res://../escape.gd"')
      assert_raises(NetworkManifest::Error) { builder.document }
    end
  end
end
