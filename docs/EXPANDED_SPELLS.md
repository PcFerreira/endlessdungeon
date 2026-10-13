# Expanded spells and companions

The three classes share 24 unique abilities. Each class can learn ten and equip them in the existing ten action slots. Press G to learn and equip abilities. The original abilities and skill ranks retain their IDs.

| Class | Ability | Effect |
| --- | --- | --- |
| Mage | Ice Lance | Deals frost damage and freezes its target for 2.2 seconds. |
| Mage | Chain Lightning | Strikes up to three nearby enemies, losing 20% damage at each jump. |
| Mage | Lantern Familiar | Summons a hovering lantern that fires at nearby enemies. |
| Sword | Quake Strike | Damages nearby enemies and stuns them for one second. Requires grounded footing. |
| Sword | Aegis | Absorbs up to 45 damage over eight seconds. |
| Sword | Ancestral Warden | Summons a grounded guardian that fights nearby enemies. |
| Spellsword | Cinder Brand | Deals initial damage, then burns for five seconds. |
| Spellsword | Siphon Touch | Heals the caster for 45% of damage actually dealt. |
| Spellsword | Runic Blade | Summons a hovering sword that attacks nearby enemies. |

Each new skill costs one point and follows the class's Power, Reserves or Specialty branch. Class damage bonuses apply to damaging spells and companions. Frozen or stunned enemies stop moving and cancel attack windups. Aegis absorbs damage after Iron Guard's reduction. Burning uses timed ticks; healing cannot exceed maximum health.

Up to two companions can be active. Recasting a companion replaces that companion; summoning a third kind replaces the oldest. Lantern Familiar lasts 24 seconds; the other two last 22 seconds. Each has health and can draw nearby enemy attacks away from the player. Hostile projectiles can hit companions at their actual height.

Companions follow routes around terrain and furniture, spawn on supported ground and fight only nearby enemies. They automatically assist against hostile or provoked creatures, leaving unprovoked peaceful creatures alone. Your selected target takes priority as an explicit command. They do not teleport to catch up. The lantern and sword deliberately hover; the warden's feet meet the ground. Combat and projectile interception are dormant in cities and the Sanctum. Companions belong to the current area and clear when travelling or dying.

Temporary effects and companions pause with gameplay and clear on save restoration. Autosaving does not dismiss active companions or barriers. Learned skills, equipped slots and cooldowns persist. Older saves may omit the nine new cooldown fields, which restore to zero; the original fifteen fields remain required. Casting follows the existing offline action guard.

The nine SVG icons, companion voxel models and spell visuals are original project assets. Casts and hits reuse the adopted sounds documented in [Combat audio](COMBAT_AUDIO.md). Companions have separate records from world NPCs and enemies.

Focused checks live in `tests/test_expanded_spell_catalogue.gd`, `tests/test_combat_summons.gd` and `tests/test_spell_effects_game.gd`. `tools/capture_expanded_spells.gd` exercises actual learning, equipping and casting, and captures the three class grimoires, nine abilities and a companion group into `artifacts/expanded-spells`.
