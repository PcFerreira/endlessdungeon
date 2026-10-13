# Icon-grid interfaces

Collection screens share the backpack's visual tiles. Items use their catalogue icon or a preview of their actual model. Each tile has a short name, a quantity or rank where useful, and a tooltip with the full label. Selected tiles have a gold border. The bottom combat dock keeps its existing MMORPG layout.

## Trading

Shop counters, workshops and outdoor markets show six columns of goods with at most 24 tiles per page. Trader stock and Your goods switch between buying and selling. Select a tile to see its description, available stock, owned quantity and coin prices. Buy and Sell use the existing finite-stock transactions, including ownership, equipment, backpack and trader-purse checks. Travelling merchants show item cards with separate coin and shard payment actions.

## Other collections

- Backpack equipment uses three icon slots. Select equipped gear to inspect or unequip it.
- Grimoire Skills shows rank badges and the selected skill's prerequisites and Learn action. Abilities shows real spell icons, descriptions and ten icon slots for action-bar assignment.
- Journal books, histories, quests and discovered places use grouped tiles inside the existing scroll area. Opening an entry keeps its full text.
- Character choices use icon cards and color swatches through the appearance catalogue. The character preview shows the resulting appearance.
- World-object and Sanctum furnishing pickers show carried and placed item thumbnails. Their existing placement, move and pickup actions remain available.
- Main menu, pause, save/load and defeat choices use icon cards. Offline creation and public-world account creation show class icon choices.

Single actions such as Return, Buy and Rotate stay beside their relevant details. Filters and numerical display settings keep compact controls. Tile labels omit keyboard suffixes; the existing keyboard bindings continue to work. Placement controls retain their keyboard instructions.

## Implementation and validation

`scripts/icon_grid.gd` provides shared symbols, tile labels, quantity badges, catalogue previews and paging. `Interface.collections` groups existing journal/menu callbacks into grids. Item previews render when visible, and delayed focus checks that a selected tile is still in the tree before focusing it.

`tests/test_icon_grids.gd` checks actual Game buy/sell, merchant payment, skill learning, action-slot assignment, equipped-item removal, palette selection, furniture placement/pickup and real journal callbacks as well as catalogue icons and paging. Existing store, inventory, merchant, world-item and furnished-home fixtures cover the corresponding gameplay and save rules.

Run the native gallery with `./godot.sh --script tools/capture_icon_grids.gd --resolution 1280x800`. It writes `artifacts/grid-*.png` using an isolated preview save directory. It opens the public-world form for a class-grid capture without submitting an account request. `tools/capture_stores.gd` captures actual shop, workshop and market trading screens.
