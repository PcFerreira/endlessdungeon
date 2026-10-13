# City property and the town watch

City-owned portable objects retain their original owner when taken or placed elsewhere. The backpack marks stolen copies. Ordinary use, discard and merchant payment cannot consume those copies. Taking a clean object remains ordinary inventory collection.

A nearby guard approaches and demands restitution before using force. The demand pauses play and offers two choices: return the city's property, or refuse and leave. Esc selects the explicitly labelled refusal. Guards also accept restitution through E after refusal. Demand is deferred while nearby monsters are actively attacking or the player is airborne.

Refusal marks that city's ownership ledger hostile. Guards pursue within eighteen cells of their home and strike at close range after a visible windup. Their damage applies inside the town's protection against monsters. They return to their patrol when the player leaves pursuit range; the outstanding debt remains. Returning the property clears hostility for its original city, including stolen copies stored on other floors or in other locations. Other cities' debts remain separate.

Guard law behavior is separate from enemy targeting, dungeon gates, kills and loot. Guard attacks award no coins or items and use deterministic cosmetic effects without consuming combat RNG. A nearby hostile watch prevents opening the Sanctum or ordinary safe-ground dialogue. Menus, demands, interiors and the Sanctum keep their existing simulation pause rules.

A nearby wanted guard also takes priority over fountain and doorway E actions. The hint offers restitution, and the fountain cannot heal the player through that same key while the watch is demanding property. Clear-city interaction priorities remain unchanged.

## Ownership, movement and saves

Wren's `WorldItems` owns the saved provenance and restitution ledger. Law enforcement reads `wanted(city_id)` and calls `refuse_return(city_id)` or `return_stolen(city_id)`. `CityLaw` owns demand presentation and guard behavior, with no second wanted ledger or additional save root.

Guard positions, paths, activity and bounded attack tick fields use the existing optional `progress.life` snapshot. Hostility and placed stolen copies use `progress.world_items`, with inventory provenance checked against that state. Old optional defaults remain supported. Immediate restoration preserves the active records; jurisdiction is reevaluated from the ownership ledger before guards move.

All guards share the existing one-route-query-per-step budget and at most 169 searched cells per query. Pursuit uses short local targets and stays within the saved town envelope. Configurable notice range, pursuit range, reach, speed, damage and attack timing live in `config/city_law.json`.

## Merchant currencies

Traveling merchants accept ordinary `gold_coin` inventory stacks or ember shards. Both balances show only spendable owned quantities. The paired offer buttons make each currency explicit; spending one leaves the other unchanged. Failed purchases restore the whole inventory snapshot, including provenance.

| Item | Coins | Ember shards |
| --- | ---: | ---: |
| Vitality Potion | 4 | 3 |
| Recovery Potion | 4 | 3 |
| Rune Lantern | 12 | 8 |

The current baseline gives one coin per normal creature kill and one shard every second kill. The prices therefore correspond to 4/12 kills for coin purchases and 6/16 kills for shard purchases when every pickup is collected and there is no other income. This is arithmetic against that implemented baseline, not a long-session balance result. Ordinary item rarity and contextual drops remain Ember's separate loot lane; coins alongside guaranteed items do not by themselves establish balanced drop rates.

The Game regression verifies the four-coin potion path with four actual generated dungeon kills, normal physical coin collection, a live merchant purchase and disk reload. Ember's ordinary bag-item policy now has a separate 20-percent chance and explicit enemy/location/class/rarity pools. Source/rate checks and this controlled purchase do not establish human expedition balance.

## Validation

```sh
./godot.sh --headless --script tests/test_city_law.gd --quit-after 600
./godot.sh --headless --script tests/test_city_law_game.gd --quit-after 600
./godot.sh --script tools/capture_city_law.gd --resolution 1280x800
```

The independent check covers demand-first decisions, bounded real movement, returning to patrol, route work limits, valid pursuit saves and corrupt path/attack rejection. The actual Game check takes a generated indoor fixture and a registered guard-test object, refuses a demand, receives guard damage, saves hostile progress, stores stolen property on a real dungeon floor, restores it through guard E, verifies city-specific debt separation and reopens the original room to check its source fixture. It also checks cleared saves/Sanctum carry. The activity check covers both currencies, insufficient payment, full-backpack rollback and stolen-coin rejection. Native captures show demand, pursuit, source restoration and coin purchases. Coverage of naturally generated outdoor market parts remains the portable renderer lane's separate acceptance check.

Current limits: guards use a bounded pursuit/attack behavior and are not ordinary killable enemies. There is no jail, fine, arrest dialogue or city reputation system in this slice. Native inspection and focused checks establish the tested flows; extended playtesting is still needed for escape tuning and guard crowding.

Final Wayfarer focused checks are clean: law decisions/movement/save validation, real indoor theft and restoration, stored-property restitution and jurisdiction separation, fountain priority, the four-kill purchase path, both currencies and prior activity/life regressions. Native demand/pursuit/restoration/purchase captures passed and were reviewed at 1280x800. Logs: `/tmp/endless-wayfarer-law-final.log`, `/tmp/endless-wayfarer-law-game-final.log`, `/tmp/endless-wayfarer-coins.log`, `/tmp/endless-wayfarer-law-native.log`. The complete checker attempts are recorded separately: one reached an in-flight WorldItems declaration, and the retained-body repeat stopped at stale imported lore before runtime. Neither is an all-lane pass. Other active geography, discovery, asset-family and loot work requires its own current validation.
