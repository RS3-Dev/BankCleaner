# Seed Bag catalog

Regenerate with `node tools/catalogs/generate_seeds.mjs`.

Source: [Seeds](https://runescape.wiki/w/Seeds), revision 37211112 (2026-10-17T07:50:40Z).

The catalog contains 136 item IDs from 136 unique entries in the seed columns of every table.
The generator reads the first item after each Farming level, follows page redirects, and resolves IDs through
the wiki API infobox_item bucket. Repeated entries such as jade vine seed are included once.
Protection payments, produce, saplings, and the seed bag itself are not seed-column entries.

Coverage follows the supplied Seeds page, including Herblore Habitat, combat plants, Dungeoneering, and the Arc.
Dungeoneering items cannot normally enter a bank and therefore will not appear in a bank snapshot.
This is a seed catalog, not a live-client verification of which seeds the bag accepts.
