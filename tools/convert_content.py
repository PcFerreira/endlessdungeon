"""Run with Blender --background --python to export workspace source models."""
import hashlib, json, re, sys
from pathlib import Path

import bpy

request = json.loads(Path(sys.argv[sys.argv.index('--') + 1]).read_text())
records = []
for job in request['jobs']:
    source, target = Path(job['source']), Path(job['target'])
    target.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if source.suffix == '.blend': bpy.ops.wm.open_mainfile(filepath=str(source))
    else: bpy.ops.import_scene.fbx(filepath=str(source), use_anim=True)
    meshes = sorted((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: o.name)
    has_animation = any(o.animation_data and (o.animation_data.action or o.animation_data.nla_tracks) for o in bpy.context.scene.objects)
    if source.suffix == '.fbx' and not has_animation and any(m.type == 'ARMATURE' for o in meshes for m in o.modifiers):
        depsgraph = bpy.context.evaluated_depsgraph_get()
        baked = []
        for obj in meshes:
            mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), depsgraph=depsgraph)
            copy = bpy.data.objects.new(obj.name + '_BindPose', mesh)
            copy.matrix_world = obj.matrix_world.copy()
            baked.append(copy)
        scene = bpy.data.scenes.new('StaticBindPose')
        for obj in baked: scene.collection.objects.link(obj)
        bpy.context.window.scene = scene
        meshes = baked
    groups = [[o] for o in meshes] if job['split'] else [list(bpy.context.scene.objects)]
    if not meshes: raise ValueError(f'No mesh geometry: {source}')
    for group in groups:
        source_name = group[0].name
        if job['split']:
            scene = bpy.data.scenes.new('ContentExport')
            obj = group[0].copy()
            obj.data = group[0].data.copy()
            obj.parent = None
            scene.collection.objects.link(obj)
            bpy.context.window.scene = scene
            group = [obj]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in group:
            obj.hide_viewport = False
            obj.hide_render = False
            obj.hide_set(False)
        bpy.context.view_layer.update()
        for obj in group:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = group[0]
        name = source_name if job['split'] else source.stem
        safe = re.sub(r'[^a-zA-Z0-9_-]+', '-', name).strip('-')
        # The digest makes names unambiguous while remaining stable as the bundle grows.
        slug = safe + '-' + hashlib.sha256(name.encode()).hexdigest()[:8]
        path = target / (slug + '.glb')
        bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=not job['split'],
                                 export_animations=not job['split'], export_cameras=False,
                                 export_lights=False, export_yup=True, use_active_scene=True)
        import struct
        content = path.read_bytes()
        length = struct.unpack_from('<I', content, 12)[0]
        document = json.loads(content[20:20 + length])
        if not document.get('meshes'): raise ValueError(f'Empty export: {source} / {name}')
        if len(document.get('scenes', [])) != 1: raise ValueError(f'Export contains unused scenes: {source} / {name}')
        records.append({'source': job['relative'], 'object': name, 'file': str(path),
                        'name': name, 'split': job['split']})
Path(request['manifest']).write_text(json.dumps({'version': 1, 'records': records}, indent=2) + '\n')
