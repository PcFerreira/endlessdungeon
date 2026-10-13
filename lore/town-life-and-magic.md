# Neighbors, lanes and civic charms

The Endless World's towns gather around a shared well. Homes, trades, food and a small public wonder belong together. The magic has a keeper, a use in local life and a custom that somebody remembers when the charm is quiet.

The six civic charm accounts below are original local traditions. Their visible forms are implemented: hovering well charms, matching roof lights and inlaid road marks. The accounts are what neighbors say about them. Their deeper origins remain open to later stories.

## Build close communities

Keep the broad wilderness between settlements. Within a town, add smaller homes and workshops beside clear lanes. A household should be close enough to its baker, mender or herbal counter that walking between them feels ordinary.

Leave the well square open for greetings and shared events. Preserve the public street cross, readable approaches, inn and market entrances. New houses can face a lane instead of the square when that gives their door a better place. Entrances need space around public conversations and books.

The implemented infill uses four neighborhood recipes. Rooflight Lanes favors homes and letter writers. Trade Row mixes supplies, herbs and books with households. Garden End keeps farmhouses and herbal counters close to crop beds. Menders Court favors homes and charm repair. Only neighborhoods with actual generated buildings appear in the town plan.

A two-level exterior suggests a lived-in upper room. The current enterable building uses the established room handler; separate upstairs rooms belong to later interior work.

## The charms people keep

| Town | Public wonder | Daily connection | Custom |
| --- | --- | --- | --- |
| Crossroads | The Lantern of Return floats above the well. | Roof beads repeat its light; the inn receives road news and return stories. | Before a neighbor leaves, someone names a place for them at supper. |
| Market | The Quiet Measure has two cups hanging from a floating beam. | Repair, exchange and the work behind an object matter to the traders. | A mender shows the finished repair before naming a price. |
| Woodland Commons | The Rootlight Crown has a small branching silhouette. | Herb beds, apothecaries and shared cuttings connect households. | A new neighbor receives a cutting to tend. |
| Caravan | The Travelers Star turns above the well. | Supply shops, letter writers and inns serve people passing through. | An arriving traveler receives a cup before being asked for a name. |
| Mushroom Common | The Spore Chorus has a stepped cap and pale stem. | Spore gardens, herbal counters and charm repair share the lanes. | A new household lends a story to the common supper. |
| Winter Hearth | The Borrowed Ember glows above the well. | Tea, winterroot beds and repaired roof lights support the hearth lanes. | Before departure, neighbors ask who will receive the traveler at the other end. |

Keep their stories particular. A woodland neighbor can care more about who shares a cutting than about an ancient cosmic explanation. A market mender can argue that a crooked handle still carries good work. A winter host can treat a promise of welcome as a practical matter.

## Place magic where life uses it

The civic silhouette belongs above the actual public well. Household lights belong above real roofs, with their positions derived from each building. Road marks belong on reserved walkable streets. These cues carry the same town identity, so a traveler can recognize the place from several approaches.

Charmwrights repair the ordinary objects that carry this custom. Apothecaries and letter shops make useful neighbors for them. Magical trades use the existing workshop and shop interiors in this pass. The existing sanctuary and fountain supply the functional recovery behavior.

Town residents offer a **Town charm** conversation topic with the generated community's account and custom. Traveling people retain their road and trade topics. Regional history retains its own evidence and sources; a charm account does not rewrite a collected historical passage.

## Authoring and implementation

The authored profiles and neighborhood recipes live in [world_areas.json](../config/world_areas.json). A town selects its `magic_profile`; its `density` record supplies additional-building bounds, a required charm trade and neighborhood use pools. Each layout supplies safe small-building candidates. Existing foundation IDs and public anchors remain stable.

The runtime guide is [TOWNS_MAGIC.md](../docs/TOWNS_MAGIC.md). Larger magical institutions, specialized shop transactions, household quests and additional upstairs rooms need their own implemented handlers before dialogue can promise them.
