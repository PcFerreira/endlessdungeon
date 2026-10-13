# Roads, patrols and creature grounds

Road merchants, couriers, pilgrims, scholars and wilderness scouts travel between neighboring towns. They follow the generated highways, stop at town approaches, rest, and turn back. Two town guards patrol the street cross and its approaches. Travelers stop and face the player at conversation distance. Press E to speak to them; their route names come from the actual linked towns.

Traveling merchants exchange ember shards for vitality potions, recovery potions and rune lanterns. Every second creature kill drops a shard alongside its existing varied loot; collect the physical pickup to spend it. The dialogue lists each price and your shard balance. A failed purchase leaves inventory unchanged, including when the backpack is full. Offers are repeatable and configured in `config/world_activity.json`; the existing inventory and journey save retain purchased goods. This feature does not implement finite merchant stock or a separate currency.

Town activity alternates watch changes and road departures, markets and gear repairs, storytelling circles, pilgrim rests and courier exchanges. The original fountain supper and local delivery retain their times and factual event IDs. Every additional episode exposes the same active/aftermath contract and leaves a short visible trace. Regional-history metadata can add notes for these event kinds. Markets and story circles put goods or books on a table; scenes use the existing clear plaza anchor and add no terrain obstacles.

Monsters spawn in three named regional grounds: a den, a hunting ground and the outskirts of an actual ruin. Names adapt to forest, meadow, desert and frost contexts. Each area owns a stable ID, center and radius. A seeded group shares an eligible species from the existing biome/facet pools; cells across a habitat boundary can select another locally eligible species. Members occupy land inside the area. Roads, bridges, town streets, water and settlement clearances are excluded. Each chunk still contains at most two planned combatants. Some terrain cannot support a full group, so quiet areas remain possible.

Surface enemies chase within their grounds plus a small margin, then stop attacking and return toward a reachable point near the center. Guards deter creatures that approach within 3.5 cells. Deterrence does not damage enemies or award kills, loot or dungeon progress. The minimap shows nearby grounds as muted rings, merchants as gold dots, guards as blue dots and other peaceful NPCs as pale dots. The location label identifies an occupied ground.

## Runtime and saved state

`WorldLife` retains up to twelve local residents/animals plus eight road travelers/guards, with twenty actor models total. Existing local routing remains limited to one query per step and 169 searched cells. Road actors move along known street/highway segments without searching the whole world. Nearby routes are generated from the current region and its neighbors; unloaded traveler positions derive from the saved world clock. Towns, fauna media, terrain and asset definitions remain owned by their existing catalogues.

Road IDs are `road:x:y:axis:slot`; town-watch IDs are `watch:x:y:slot`. Saved records include point, current short target, heading, activity, next-decision tick, waypoint, direction and rest-until tick. Validation rejects malformed IDs, positions outside the owning road/town envelope, nonfinite values and invalid waypoints. Restoring the active set preserves its saved positions before subsequent streaming populates new groups. Saves without life progress retain the existing deterministic defaults. This activity feature adds no geography reset.

The world clock advances in unpaused overworld and dungeon play. Dialogue, readers, menus, death, interiors and the Sanctum keep their existing pause behavior. Travelers and guards stay in the peaceful actor scheduler; combatants, gate counts, reward lists and combat RNG remain separate.

## Validation

```sh
./godot.sh --headless --script tests/test_world_activity.gd --quit-after 600
./godot.sh --headless --script tests/test_world_activity_game.gd --quit-after 600
./godot.sh --script tools/capture_world_activity.gd --resolution 1280x800
```

The world check covers physical road travel, patrols, bounds, JSON restoration, rejected travel records, deterministic reconstruction, recurring episode variety, barter and seeded clustered encounters. The gameplay check exercises actual E dialogue, purchases, modal freeze, disk saves, monster leashes, guard deterrence and Sanctum carry. Native captures show the watch, merchant offers and purchase feedback, a town market, and naturally streamed creature grounds. Longer playtesting remains necessary for repetition, travel density and sustained performance.

Latest Wayfarer checks: the independent activity group and Game compile-only check pass after the final offscreen/species/config refinements. Both activity groups, the original living runtime and broad enemy regression passed against the earlier coherent imported snapshot. Native activity capture passed and five scenes were reviewed at 1280x800. Later Game/native/full-suite retries encountered the ongoing shared construction/asset refresh; catalogue freshness remains pending its serialized completion. These earlier passes do not certify another lane's in-flight assets. Logs: `/tmp/endless-wayfarer-activity.log`, `/tmp/endless-wayfarer-game.log`, `/tmp/endless-wayfarer-life.log`, `/tmp/endless-wayfarer-native.log`, `/tmp/endless-wayfarer-compile.log`, `/tmp/endless-wayfarer-freshness.log`.

## City law and coin purchases

[City law](CITY_LAW.md) connects the watch to actual portable-property ownership, with demand-first enforcement, saved refusal, bounded pursuit and restitution from backpack or placed storage. Merchants now accept explicit coin prices alongside shard barter; the linked guide records both prices and the current kill-rate arithmetic.
