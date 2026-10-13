# Windows release

The current Windows 64-bit release is `builds/windows/EndlessWorld.exe`. The shareable archive is `builds/EndlessWorld-windows-x86_64.zip`; extract it and double-click `EndlessWorld.exe`. Game data is embedded in the executable. Keep its credits and 211 source/license notices when redistributing it. Offline play is included; a shared world requires a compatible running server.

The 2026-10-13 build includes fourteen wider biomes with named atmosphere, twenty-eight micro-biomes, eight wilderness construction types and the current streaming/render-loading fixes. Begin a new journey for edition-7 exploration; existing saves retain their saved world edition.

This release uses the verified official Godot 4.7.2 x86_64 template. The Windows preset embeds the pack, uses the Compatibility renderer and retains raw SVG files needed by runtime readers. The Web preset keeps its existing options. The normal EXE uses standard rendering; `EndlessWorld-ThreadedRendering.bat` offers the existing experimental separate rendering thread. This local release is unsigned.

The current release was exported from `.tools/windows-streaming-hotfix/`. Its `source-snapshot.json` records the captured main-project inputs. Only the snapshot's network manifest was refreshed; the main authority manifest and running pinned server were preserved. After archiving the snapshot's existing Windows outputs, rebuild its executable with:

```sh
ruby .tools/windows-streaming-hotfix/tools/build_windows.rb
```

For a future main-project build, coordinate stable source and current caches/manifest first. Archive any existing `builds/windows`, Windows ZIP or unfinished `builds/windows-next` before running `ruby tools/build_windows.rb`. The helper refuses to overwrite them and checks the network manifest rather than changing live authority. Accepted current logs are in `builds/windows-logs/`.

Export and isolated embedded-pack checks pass without engine diagnostics. Checks cover the x86_64 PE header, 4,042 dynamic resources, runtime JSON/SVG/notices and exclusion of development folders. The packed-content check validates all fourteen biome/atmosphere profiles, twenty-eight micro-biomes and eight construction types, then builds 144 geometry variants across both families and claim states.

The isolated host-engine smoke check instantiates the actual packed Game, creates an edition-7 character, begins in Lanternwake, saves/loads, departs through the physical Worldgate, checks wilderness exploration eligibility and opens inventory. Temporary saves and settings are removed. Release inputs remain unchanged through export, and the final ZIP passes integrity checks.

The current executable is 546,529,640 bytes, with SHA-256 `a00a07bebcd920101dd94651740b5a50ff6ca9acd1cb0bd829c4c3b7c3647da3`. `build-report.json` records its exact content/source revisions, template version, build time and validation boundary. A ZIP checksum is available in `builds/EndlessWorld-windows-x86_64.zip.sha256`.

These checks ran on macOS against the Windows executable's embedded pack. The current EXE has not been executed on Windows, and this packaging pass did not run the full combined test suite. Windows graphics, input and performance remain to be checked on the target machine.

The earlier performance release is preserved in `builds/windows-previous-979c27b1-20261013T223320Z/`, with its ZIP at `builds/EndlessWorld-windows-x86_64-previous-979c27b1-20261013T223320Z.zip`. Its executable SHA-256 is `979c27b1f8ecbd006e65a63849cb31b2442ba9d3d24c87cadead5b793b4b286b`. Earlier top-level logs were archived in `builds/windows-logs-previous-979c27b1-20261013T223320Z/`; those logs included a rejected export and do not describe the current package.

The first release ran successfully on Windows according to the user and remains under `builds/windows-original-65020363/`. Its original performance-update source snapshot remains in `.tools/windows-performance-release/`. The timing reports in [Streaming performance](STREAMING_PERFORMANCE.md) describe earlier source snapshots; this package was rebuilt without a new Windows timing claim.

## Release chunk and icon hotfix

The current `a00a07be` build corrects calls inside assertions that production runtimes omit. Chunk worker startup, item SVG loading and menu symbol SVG loading now execute normally; avatar preview restoration and fallback geometry conversion also run outside assertions. The user reported stalled streaming and missing icons in the preceding `9be7fddf` Windows release. That package is preserved under `builds/windows-previous-9be7fddf-20261013T231549Z` and its matching archived ZIP.

An official 4.7.2 macOS release template reproduced the old executable embedded pack failure with debug=false: worker=false, zero delivered chunks and empty menu/item images. The corrected exact Windows executable embedded pack then passed the same release-runtime regression: physical Worldgate departure, three newly prepared/promoted 25-chunk rings, 13 menu symbols and 2758 SVG item entries with actual nonempty images. Packed-content and ordinary host startup/save checks also pass. This exercises production assertion stripping and packed game logic on the host; Windows-native graphics and timing have not been retested.

The Windows builder now requires this release-runtime regression before accepting a package. On macOS, `tools/install_windows_templates.rb` also installs the checksum-verified official release runtime. Run `ruby tools/check_release_runtime.rb builds/windows/EndlessWorld.exe` to repeat the exact embedded-pack check. Its probe and override exist only in a private temporary folder and are removed afterward; they are excluded from the shipped game.
