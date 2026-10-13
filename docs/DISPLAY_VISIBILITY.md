# Enemy visibility and display options

Owner: Wren. Enemies no longer disappear outside an 8.5-cell circle around the player. Spawn, ordinary updates and save restoration use one rendering rule. Surface enemies remain available to the renderer throughout the loaded area; the renderer handles the camera frustum and physical depth occlusion. Underground enemies remain hidden until their terrain cell has been discovered, then stay visible wherever the camera can see them.

Rendering does not activate an enemy. Existing 7.5-cell detection, combat line of sight, attack ranges, pursuit and path timing remain unchanged. The existing streamed-world bounds still control which enemies exist. This change does not add a global enemy simulation or reveal undiscovered dungeon rooms.

## Resolution controls

Options includes a window-resolution selector with common 16:9, 16:10 and 4:3 sizes from 1024x640 through 3840x2160, including 1080p, 1440p, 2560x1600 and 3440x1440. Presets that exceed the current display's usable window area are disabled. A manually resized valid window appears as an additional current choice.

Fullscreen follows the display's desktop resolution. The window-size selector is disabled while fullscreen is active, and the previously chosen window size is restored when returning. F11 uses the same fullscreen setter as Options. Changing resolution resizes the window while retaining the project's existing aspect-preserving canvas and camera behavior.

Audio, fullscreen and window-resolution preferences save in `user://settings.cfg`, independently of journey slots. Existing settings without a resolution use the current/default window size. Invalid stored resolution values are ignored. Windowed sizes are fitted to the current screen when applying a preference from another display.

The implementation uses Godot's recommended `Window.size` setter and queries the usable screen rectangle. [DisplayServer API](https://docs.godotengine.org/en/stable/classes/class_displayserver.html#class-displayserver-method-window-set-size). The current canvas scaling retains the established base-size/aspect policy. [Window scaling API](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-property-content-scale-size).

## Verification

```sh
./godot.sh --headless --script tests/test_visibility_display.gd --quit-after 600
./godot.sh --script tools/capture_visibility_display.gd --resolution 1280x800
```

The focused test reproduces the old rendering failure at 14 cells and covers spawn/update/load visibility, inactive distant enemies, player-LOS independence, dungeon discovery fog, resolution validation/choices, fullscreen/F11 return and real settings-file persistence. Camera, gameplay, save/load and window-close regressions also pass against the imported snapshot used for this task.

The native helper verifies camera-visible distant models at normal and maximum outdoor zoom, menu bounds, signal-driven resolution changes, custom manually resized windows, fullscreen return and settings reload. Native sizes tested are 1024x768, 1280x720, 1280x800, 1600x900, 1920x1080 and 2560x1440. The fullscreen capture uses the local 3360x2100 display. Larger preset selection is not claimed as tested hardware behavior. Captures use isolated journey/settings paths under `artifacts/display-preview-saves`.

Logs: `/tmp/endless-wren-test_visibility_display.log`, `/tmp/endless-wren-test_camera.log`, `/tmp/endless-wren-test_gameplay.log`, `/tmp/endless-wren-test_save_game.log`, `/tmp/endless-wren-test_save_exit.log`, and `/tmp/endless-wren-display-native.log`. Captures: `artifacts/enemies-visible-zoom-*.png` and `artifacts/display-options-*.png`.

The final focused visibility/display repeat also passes cleanly after the concurrent activity/loot compile corrections (`/tmp/endless-wren-visibility-final.log`). The final native helper exits 0 without engine errors or warnings, including the manually resized 1400x800 choice and resolution restoration after the macOS fullscreen transition. Representative enemy, small/large Options and fullscreen captures were visually reviewed. All fixtures preserve the user's actual journey/settings files.

A fresh complete importer/checker pass depends on the concurrent creature/item/environment bundle's build and import handoff. The freshness check currently reports out-of-date generated output (`/tmp/endless-wren-display-freshness.log`). This task's targeted checks are separate from that in-progress asset expansion. Whole-game GPU performance at 4K and other display/platform combinations remain unmeasured.
