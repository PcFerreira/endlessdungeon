# Small wild places

Edition 7 adds 28 named micro-biomes inside the fourteen large regions. These pockets usually have a radius of 8 to 12 cells: fairy rings, sheltered groves, memorial clearings, fungal nurseries, basalt vents, crystal pockets and natural waterbanks. They use seeded locations and local plant arrangements. Water-dependent pockets require existing natural water; generation does not create ponds or alter terrain height.

Approach a small cache and press E to study the place. A successful first visit grants two to five biome materials and eight to twenty owned gold coins. If either reward cannot fit, the backpack and claim remain unchanged. Returning to a studied cache shows its description and open body without granting the reward again.

Each four different pocket types studied awards one skill point. Additional caches of an already studied type still give their individual material and coin rewards, but do not advance that milestone. The 28 types therefore support at most seven exploration skill points per journey. Discovered places and claims appear in the field journal and survive disk loading, Sanctum visits and Worldgate travel.

| Main biome | Micro-biomes |
| --- | --- |
| `greenwood` | Dewlight Ring; Bramble Nook |
| `meadows` | Starfall Meadow; Sage Hollow |
| `desert` | Cactus Shade; Hidden Oasis Bank |
| `frostlands` | Frostwater Hollow; Resin Copse |
| `dense_forest` | Ancient Grove; Moth Moss Ring |
| `haunted_hollows` | Forgotten Memorial; Lantern Wake |
| `marsh` | Firefly Fen; Silver Reed Bank |
| `jungle` | Bamboo Hollow; Ginger Shelter |
| `autumn_woodland` | Harvest Glade; Amber Copse |
| `fungal_grove` | Mooncap Colony; Mycelial Nursery |
| `volcanic_wastes` | Basalt Vent; Cinder Shelf |
| `highlands` | Windward Outcrop; Thyme Shelter |
| `coast` | Tide Garden; Whisper Shell Cove |
| `crystal_tundra` | Crystal Pocket; Glass Lichen Shelf |

The authored Lanternwake island, finite realms and shared clients keep their own exploration rules. The inherited wilderness outside Lanternwake is eligible after normal fresh-character Worldgate departure. Natural pockets and their approaches avoid roads, town plots, independent structures and dungeon entrances.

The controller retains at most eight visible cache markers, local plans for the loaded ring and 4,096 discovered identities. Original marker meshes share a bounded 24-template cache. World composition retains at most 32 micro-patch records. The journal shows the latest 64 discoveries while keeping the full claim ledger.

Author profiles in `config/micro_biomes.json`. `MicroBiomeCatalog` resolves authoritative locations and existing reward materials. `BiomeComposition` gives them local plant arrangements, `MicroBiomeView` builds the original closed/open geometry, and `MicroBiomeExploration` handles discovery and reward collection. Its state is nested in the existing Exploration snapshot, preserving older saves without a separate save format.

Focused checks pass all 28 authored types, 14 actual generated ecologies and 2,188 catalogue/location/focal-space assertions, including real wet pockets and inherited HubWorld wilderness. Fairy rings and fungal nurseries reserve an empty 2.25-cell cache core and use sparse low colored caps. The original marker matrix passes 112 closed/open bodies and 1,097 geometry checks. A source-stable actual Game check explores five places of four different types, awards 68 coins and one skill point, verifies atomic backpack rollback and journal entries, and preserves claims through fresh disk loading and actual Sanctum/Worldgate returns.

`artifacts/micro-biomes/native-seed91` contains 32 reviewed native Game views: actual hub arrival and Worldgate departure, closed/open caches in all fourteen ecologies, and both ends of the field journal. The helper uses deterministic `Game.start_run(91, 7)`, production `FloatingHub.start()` and actual E departure; the separate new-character UI flow has headless acceptance. Fourteen actual E claims give their configured material and coin rewards and three skill milestones. The final capture has identical before/after hashes for 47 source inputs, completed warmup and visible gameplay UI. These are selected views and focused gameplay checks, rather than a full combined acceptance run.

That review caught dense generic mushrooms obscuring the nursery cache. `artifacts/micro-biomes/fungal-focus-seed91` supersedes the fairy-ring and nursery presentation with eight current closed/open views from opposing cameras. All eight were reviewed after the low-cap and empty-core correction; cache bodies and labels remain readable in both directions. The targeted capture has 52 unchanged source hashes and verifies both actual E payouts without changing gameplay RNG.
