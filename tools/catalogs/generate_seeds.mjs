// Generate Seed Bag's item catalog from every seed column on the wiki
// Usage from the repository root: node tools/catalogs/generate_seeds.mjs
import fs from 'node:fs';
import { wikitexts, resolveTitles, itemRows } from './wiki.mjs';

const page = (await wikitexts(['Seeds'])).Seeds;
// Each data row begins with the Farming level, then the seed's picture/link
// Some levels span several protection rows; older tables use separate pictures
const titles = [...new Set(page.text.split(/\n\|-\s*\n/).map(row => row.match(
    /^\|\s*(?:rowspan\s*=\s*\d+\s*\|\s*)?\d+\s*\n\|\s*(?:\[\[File:[^\n]+\n\|\s*)?(?:\{\{plinkt\|([^|}]+)|\[\[([^\]|]+))/i
)).filter(Boolean).map(match => (match[1] || match[2]).trim()))];
if (titles.length < 100) throw new Error('Seed tables were not read completely');
const resolved = await resolveTitles(titles);
if (Object.values(resolved).some(title => !title)) throw new Error('A seed page could not be resolved');
const rows = await itemRows([...new Set(Object.values(resolved))]);
for (const title of titles) {
    if (!rows.some(row => row.page_name === resolved[title])) throw new Error('Missing seed ID: ' + title);
}
const items = new Map();
for (const row of rows) {
    for (const id of row.item_id) {
        if (!Number.isInteger(Number(id)) || Number(id) <= 0) throw new Error('Invalid seed ID: ' + id);
        items.set(Number(id), row.item_name);
    }
}
fs.writeFileSync('bankcleaner/data/seed_bag_objects.lua', [
    '-- Seeds the seed bag stores',
    'return {',
    ...[...items].sort((a, b) => a[0] - b[0]).map(([id, name]) => `    [${id}] = true, -- ${name}`),
    '}', '',
].join('\n'));
console.log(JSON.stringify({ revision: page.revid, timestamp: page.timestamp, seeds: titles.length, objects: items.size }));
fs.writeFileSync('docs/SEED_CATALOG_SOURCES.md', [
    '# Seed Bag catalog', '',
    'Regenerate with `node tools/catalogs/generate_seeds.mjs`.', '',
    `Source: [Seeds](https://runescape.wiki/w/Seeds), revision ${page.revid} (${page.timestamp}).`, '',
    `The catalog contains ${items.size} item IDs from ${titles.length} unique entries in the seed columns of every table.`,
    'The generator reads the first item after each Farming level, follows page redirects, and resolves IDs through',
    'the wiki API infobox_item bucket. Repeated entries such as jade vine seed are included once.',
    'Protection payments, produce, saplings, and the seed bag itself are not seed-column entries.', '',
    'Coverage follows the supplied Seeds page, including Herblore Habitat, combat plants, Dungeoneering, and the Arc.',
    'Dungeoneering items cannot normally enter a bank and therefore will not appear in a bank snapshot.',
    'This is a seed catalog, not a live-client verification of which seeds the bag accepts.', '',
].join('\n'));
