# Breath of the Wild: world design research

Research date: 2026-10-12. Purpose: identify design ideas for the Endless Realm's procedural overworld. This is an author and developer reference, not player-facing lore.

The strongest application is to generate a sequence of discoveries with choices between them. Terrain, routes, settlements, and small details should work together to make the next few minutes worth exploring.

## Sources and evidence boundaries

This pass inspected Nintendo's official game description, a Nintendo developer interview that retrospectively discusses Breath of the Wild, the official CEDEC field-design session description, and eight Nintendo presentation diagrams reproduced by 4Gamer. The diagrams were viewed directly. They are primary presentation material hosted in conference coverage; the recommendations below do not depend on the reporter's interpretation.

Nintendo's making-of series and the GDC 2017 talk are linked for further viewing. Their video contents were not reviewed in full. This research does not establish Nintendo's internal terrain-generation algorithm, a universal encounter interval, or an exact formula for every location.

Treat the findings as authored design principles that we can translate into procedural constraints. The proposed generator passes in [World generation](../world-generation.md) are our design, not a description of Nintendo's implementation.

## 1. The player chooses a destination by looking

Nintendo describes climbing towers and mountain peaks to survey destinations, then setting a personal route. Its scope and map support that exploration. [Nintendo's official game description](https://www.nintendo.com/us/store/products/the-legend-of-zelda-breath-of-the-wild-us/)

Our interpretation: scenery supplies information that a player can act on. A recognizable object becomes useful when the player can identify an approach and understand why it might be worth visiting.

Endless Realm application: give a place a readable silhouette or local clue before asking the player to open the atlas. Our isometric camera sees a limited area, so start with nearby reveals and recognizable approaches. A distant landmark requires deliberate support for rendering beyond the usual streamed detail.

## 2. An obstacle offers a choice and controls a reveal

One Nintendo diagram shows a person approaching a triangular hill, with arrows for going over or around it. A second shows an object progressively emerging from behind the hill. A third arranges landforms of several sizes around landmarks. [Route-choice diagram](https://www.4gamer.net/games/341/G034168/20170901120/TN/054.jpg), [gradual-reveal diagram](https://www.4gamer.net/games/341/G034168/20170901120/TN/055.jpg), [arrangement diagram](https://www.4gamer.net/games/341/G034168/20170901120/TN/056.jpg)

Our interpretation: the useful rule concerns approach options and controlled visibility. A literal triangle on the terrain is only one way to achieve that effect.

Endless Realm application: offer an ordinary route around a rocky rise and an optional traversable route across it. Use the rise to delay the view of a ruin or clearing. Check that the reveal survives the fixed camera angle and cutaway rendering. If it does not, use a bend, forest opening, or screen-boundary reveal instead.

Both routes need a purpose. One might be direct and exposed; the other longer, with a sheltered rest stop or readable survey marks. Do not build two corridors with identical experiences solely to satisfy a branch count.

## 3. A route can interrupt and restore interest

The presentation's route sequence begins with a straight approach to a tower. Later diagrams bend the road around terrain, hide the tower, introduce another structure, and restore the tower to view. [Initial approach](https://www.4gamer.net/games/341/G034168/20170901120/TN/057.jpg), [bent route](https://www.4gamer.net/games/341/G034168/20170901120/TN/058.jpg), [hidden destination](https://www.4gamer.net/games/341/G034168/20170901120/TN/059.jpg), [intermediate structure](https://www.4gamer.net/games/341/G034168/20170901120/TN/060.jpg), [destination revealed again](https://www.4gamer.net/games/341/G034168/20170901120/TN/061.jpg)

Our interpretation: a player can retain a destination while responding to discoveries along the route. Temporary loss of sight creates anticipation when enough other information remains to continue.

Endless Realm application: connect a town, roadside clue, and ruin as one short expedition. Place the clue where it becomes visible during travel. Keep a readable way onward and a reliable way home. Roads should follow the intended experience and the terrain, with authored local patterns that the generator can vary.

## 4. Density and vegetation carry design intent

The official CEDEC session description explicitly discusses landmarks, natural vegetation, sparse and dense areas, and intentions about what players should notice or overlook. Its speakers were director Hidemaro Fujibayashi and terrain lead artist Makoto Yonezu. [Official CEDEC 2017 session](https://cedec.cesa.or.jp/2017/session/GD/s59007c6395fd6.html)

Our interpretation: an open area, a thicket, and a clearing can serve different purposes even within the same biome. Uniformly distributed objects cannot express all of those purposes.

Endless Realm application: reserve clearings and approach corridors, cluster vegetation elsewhere, and place small discoveries where terrain or vegetation makes them legible. Use the existing biome noise for broad environmental character, then add local composition rules. Do not interpret this as a claim that a certain number of objects per chunk guarantees good pacing.

## 5. Different destinations support different needs

Nintendo presents shrines as challenge and reward sites, villages as distinct communities, and stables as places to recover and prepare. It also describes gathering, weather-sensitive equipment, and several travel methods. [Nintendo's official game description](https://www.nintendo.com/us/store/products/the-legend-of-zelda-breath-of-the-wild-us/)

Our interpretation: a trip becomes more useful when its destinations serve different purposes. Rest, challenge, supplies, social contact, and information can support one another.

Endless Realm application: preserve the sanctuary town's recovery role and the dungeon's combat role. Add books, views, local customs, and future travelers as different kinds of discoveries. A mundane repair shelter could eventually become useful without becoming another combat dungeon.

Environment-driven equipment, cooking, swimming, horses, and gliding are future scope decisions. The current game should not promise them through its terrain or dialogue. Existing combat abilities are enough to begin testing route variety.

## 6. The world teaches what actions to expect

In Nintendo's later Tears of the Kingdom interview, Dohta explicitly connects player-expected actions to the previous game. The team also describes visual rules for immovable crates and unbreakable jars. Those specific examples belong to the sequel discussion. [Nintendo developer interview, Part 5](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-9-the-legend-of-zelda-tears-of-the-kingdom-part-5/)

Our interpretation: repeated visual cues should establish reliable expectations. This matters even before a large physics system exists.

Endless Realm application: distinguish ordinary pots, future readable objects, actual dungeon entrances, and Potfolk characters. A glowing gate should signal an interaction the game can perform. A decorative arch should not accidentally use every cue assigned to a dungeon entrance.

The same principle applies to magic. An Ember Orb does not imply that forests burn unless the game implements that rule. If we later add material interactions, define and test a small consistent set before building encounters around them.

## 7. A place becomes memorable through continuity

Nintendo's retrospective interview describes Hyrule as a familiar place whose existing design supported new discoveries in the sequel. Takizawa discusses adding surprises while preserving that familiar world. [Nintendo developer interview, Part 1](https://www.nintendo.com/us/whatsnew/ask-the-developer-vol-9-the-legend-of-zelda-tears-of-the-kingdom-part-1/)

Our interpretation: recognizing a place is part of exploration. Endless generation needs enough stable relationships for people to learn and remember their surroundings.

Endless Realm application: give generated districts durable identities and store or deterministically reproduce their local history. A roadside milestone, a keeper's story, and a found letter can point to the same ruin. New country appears beyond known country. Reloading a chunk should preserve the places a player has learned.

## Translating these ideas to our camera and generator

The source inspected during this pass already has 16-cell chunks, 64-cell regions, one city and two ruins per region, layered elevation noise, and jumping. The camera is fixed and orthographic. These observations come from the current project source, not older prose that describes flat terrain.

| Design idea | Endless Realm adaptation | Main constraint |
| --- | --- | --- |
| Survey a destination | Recognizable local landmarks; later, distant landmark representations | Limited camera view and streamed geometry |
| Go over or around terrain | A pass or gentle stepped route beside a lower road | Current movement rules and reachable height changes |
| Gradual reveal | A woodland opening or road bend exposes a ruin in stages | Cutaway rendering may erase intended occlusion |
| Distinct destination roles | Sanctuary, dungeon, future book site, traveler stop, and viewpoint | Several interactions still need implementation |
| Environmental expectations | Consistent visual and interaction cues | Rendered visibility differs from combat line of sight |
| Familiar world with discoveries | Stable district facts and linked local stories | State ownership and future save support |

The full proposal, including deterministic generation, chunk ownership, placement examples, and validation, is in [World generation](../world-generation.md).

## Further primary viewing

| Reference | Purpose |
| --- | --- |
| [Nintendo's making-of series](https://www.nintendo.com/en-gb/News/2017/March/Go-behind-the-scenes-with-the-making-of-The-Legend-of-Zelda-Breath-of-the-Wild-1206592.html) | Developer explanations of exploration, scale, story, and production |
| [Open-Air Concept, Nintendo of America](https://www.youtube.com/watch?v=vLMGrmf4xaY) | Direct developer discussion of exploration freedom |
| [GDC 2017: Change and Constant](https://www.gdcvault.com/play/1024562/Change-and-Constant-Breaking-Conventions) | Direct presentation by Fujibayashi, Dohta, and Takizawa |

Do not treat a session listing as evidence of unreviewed implementation details. Detailed physics and chemistry-engine research can be a separate pass if we decide to pursue environmental interactions.
