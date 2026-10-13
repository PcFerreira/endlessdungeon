require 'digest'

module ReleaseInputs
  def self.snapshot(root = Dir.pwd)
    paths = Dir.glob('{scripts,scenes,addons/web_raw_files}/**/*', base: root).select do |path|
      File.file?(File.join(root, path)) && %w[.gd .tscn .tres .cfg].include?(File.extname(path))
    end
    paths += Dir.glob('{config/**/*.json,assets/render_cache/**/*,assets/landmark_cache/**/*,assets/town_voxels/**/*,assets/combat_audio/**/*,assets/**/*.gdshader}', base: root).select do |path|
      File.file?(File.join(root, path))
    end
    paths += %w[project.godot export_presets.cfg]
    paths.uniq.sort.to_h { |path| [path, Digest::SHA256.file(File.join(root, path)).hexdigest] }
  end
end
