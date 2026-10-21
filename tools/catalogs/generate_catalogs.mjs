// Generate the storage catalogs from the RuneScape Wiki
// Usage from the repository root: node tools/catalogs/generate_catalogs.mjs
// Writes bankcleaner/data/{storage_chest,diango,storm_barn,workbench_artefact,material_storage}_objects.lua
// and docs/CATALOG_SOURCES.md; every API response is cached under WIKI_CACHE (default: the OS temp folder)

import fs from 'node:fs';
import { api, itemRows, resolveTitles, wikitexts, categoryMembers, renderedPage, backlinks } from './wiki.mjs';

const WIKI = 'https://runescape.wiki/w/';
const DIANGO_CATEGORY = 'Category:Reclaimable from Diango';
// Infobox Set fields that name a worn or held piece
const SET_SLOT = /^(head|cape|neck|ammo|body|legs|hands|feet|ring|pocket|mhand|ohand|2hand|weapon|shield|aura)\d*$/;

const today = new Date().toISOString().slice(0, 10);
const sources = [];

// Decode the HTML entities the parser writes into titles
const decode = text => text.replace(/&#39;/g, "'").replace(/&quot;/g, '"').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>');
const pageURL = title => WIKI + encodeURIComponent(title.replace(/ /g, '_')).replace(/%2F/g, '/').replace(/%3A/g, ':');

// Read a source page's wikitext and record its revision
async function sourceText(title, anchor) {
    const page = (await wikitexts([title]))[title];
    if (!page) throw new Error('source page missing: ' + title);
    sources.push({ title, anchor, revid: page.revid, timestamp: page.timestamp });
    return page.text;
}

// Return the text of every {{Name ...}} template call, braces balanced
function templates(text, name) {
    const found = [];
    const pattern = new RegExp('\\{\\{\\s*' + name.replace(/ /g, '[ _]'), 'gi');
    let match;
    while ((match = pattern.exec(text)) !== null) {
        let depth = 0;
        for (let index = match.index; index < text.length - 1; index++) {
            if (text[index] === '{' && text[index + 1] === '{') { depth++; index++; continue; }
            if (text[index] === '}' && text[index + 1] === '}') {
                depth--;
                index++;
                if (depth === 0) { found.push(text.slice(match.index, index + 1)); break; }
            }
        }
    }
    return found;
}

// Name an item row, with its version when the page has several
function rowName(row) {
    const sub = String(row.page_name_sub || '');
    const version = sub.includes('#') ? ' (' + sub.split('#').slice(1).join('#') + ')' : '';
    return String(row.item_name || row.page_name) + version;
}

// Group item rows by page
async function rowsByPage(pages) {
    const grouped = {};
    for (const row of await itemRows([...new Set(pages)])) (grouped[row.page_name] ||= []).push(row);
    return grouped;
}

// Read an Infobox Set's piece names
function setPieces(text) {
    const names = new Set();
    for (const set of templates(text, 'Infobox Set')) {
        for (const line of set.split('\n')) {
            const field = line.match(/^\s*\|\s*([\w]+)\s*=\s*(.*?)\s*$/);
            if (field && SET_SLOT.test(field[1]) && field[2] !== '') names.add(field[2]);
        }
    }
    return [...names];
}

// Read the item IDs an Infobox Pet names
function petItems(text) {
    const ids = [];
    for (const pet of templates(text, 'Infobox Pet')) {
        const field = pet.match(/\|\s*itemid\s*=\s*([\d,\s]+)/);
        if (field) ids.push(...field[1].split(',').map(id => Number(id.trim())).filter(Boolean));
    }
    return ids;
}

// Resolve source titles to items
// An item page gives its own IDs, a pet page its item ID, a set its pieces, and a list page
// (options.reclaim) the linked item pages that link back to it; a piece counts when it is in
// options.reclaim.category or its page names options.reclaim.word
async function expand(titles, options = {}) {
    const resolved = await resolveTitles(titles);
    const pages = [...new Set(Object.values(resolved).filter(Boolean))];
    const direct = await rowsByPage(pages);
    const needText = pages.filter(page => !direct[page]);
    const texts = await wikitexts(needText);
    const pieces = {}, pets = {};
    for (const page of needText) {
        const text = texts[page] ? texts[page].text : '';
        const ids = petItems(text);
        const names = setPieces(text);
        if (ids.length > 0) {
            pets[page] = ids;
        } else if (names.length > 0) {
            pieces[page] = { method: 'set', names };
        } else if (options.reclaim) {
            // Only a bullet or table cell holding nothing but a link lists a piece; prose links do not
            const links = text.split('\n').map(line => line.match(
                /^\s*[*!|]*\s*(?:\[\[([^\]|#]+)(?:\|[^\]]*)?\]\]|\{\{plinkt?\|([^|}]+)[^}]*\}\})\s*$/))
                .filter(Boolean).map(match => (match[1] || match[2]).trim());
            // A piece links back to its list page; a disambiguation page's entries need not
            const disambiguation = /\{\{\s*Disambig/i.test(text);
            const linking = disambiguation ? null : new Set(await backlinks(page));
            const kept = [...new Set(links)].filter(link => linking === null || linking.has(link));
            if (kept.length > 0) pieces[page] = { method: 'list', names: kept };
        }
    }
    const pieceTitles = Object.values(pieces).flatMap(entry => entry.names);
    const pieceResolved = await resolveTitles(pieceTitles);
    const pieceRows = await rowsByPage(Object.values(pieceResolved).filter(Boolean));
    const mentions = {};
    if (options.reclaim) {
        const unlisted = Object.values(pieceResolved).filter(page => page && pieceRows[page]
            && !options.reclaim.category.has(page));
        const pieceTexts = await wikitexts(unlisted);
        for (const page of unlisted) mentions[page] = (pieceTexts[page] ? pieceTexts[page].text : '').includes(options.reclaim.word);
    }
    const results = {};
    for (const title of titles) {
        const page = resolved[title];
        if (page === null) {
            results[title] = { page: null, method: 'missing', items: [], excluded: [] };
            continue;
        }
        if (direct[page]) {
            results[title] = { page, method: 'item', items: direct[page].map(row => ({ rows: row, page })), excluded: [] };
            continue;
        }
        if (pets[page]) {
            results[title] = { page, method: 'pet', excluded: [],
                items: [{ rows: { item_id: pets[page], item_name: page, page_name: page }, page }] };
            continue;
        }
        const entry = pieces[page];
        if (!entry) {
            results[title] = { page, method: 'not an item', items: [], excluded: [] };
            continue;
        }
        const items = [], excluded = [];
        for (const name of entry.names) {
            const piecePage = pieceResolved[name];
            const rows = piecePage ? pieceRows[piecePage] : null;
            if (!rows) {
                // A list page links plenty of non-items, so only a set's missing piece is a problem
                if (entry.method === 'set') excluded.push({ name, reason: piecePage ? 'no item infobox' : 'missing page' });
            } else if (options.reclaim && !options.reclaim.category.has(piecePage) && !mentions[piecePage]) {
                excluded.push({ name: piecePage, reason: `not in ${options.reclaim.category.name} and page never names `
                    + options.reclaim.word });
            } else {
                for (const row of rows) items.push({ rows: row, page: piecePage });
            }
        }
        results[title] = { page, method: entry.method, items, excluded };
    }
    return results;
}

// Flatten expansion results into { id, name, entry } items, recording problems
function collect(results, report, filter = () => true) {
    const items = [];
    for (const [title, result] of Object.entries(results)) {
        if (result.items.length === 0) report.unresolved.push({ title, reason: result.method });
        for (const excluded of result.excluded) report.excluded.push({ title, ...excluded });
        for (const item of result.items) {
            const name = rowName(item.rows);
            if (!filter(name)) {
                report.excluded.push({ title, name, reason: 'excluded variant' });
                continue;
            }
            for (const id of item.rows.item_id || []) items.push({ id, name, entry: title, method: result.method });
        }
    }
    return items;
}

// Storage Chest: every row of the reclaimable tables, with alternatives named in the row
async function storageChest() {
    const text = await sourceText('Storage Chest', 'Reclaimable items');
    const body = text.split('<onlyinclude>')[1].split('</onlyinclude>')[0];
    const titles = [], caveats = [];
    for (const line of body.split('\n')) {
        const row = line.match(/^\|\s*\{\{plinkt\|([^|}]+)[^}]*\}\}(.*)$/);
        if (!row) continue;
        titles.push(row[1].trim());
        const rest = row[2];
        for (const alt of rest.matchAll(/\{\{plinkt?\|([^|}]+)[^}]*\}\}/g)) titles.push(alt[1].trim());
        for (const alt of rest.matchAll(/\/\s*\[\[([^\]|]+)(?:\|[^\]]*)?\]\]/g)) titles.push(alt[1].trim());
        const note = rest.replace(/\{\{Cite[^]*$/, '').replace(/\{\{plinkt?\|([^|}]+)[^}]*\}\}/g, '$1')
            .replace(/\[\[(?:[^\]|]+\|)?([^\]]+)\]\]/g, '$1').trim();
        if (/^(unless|if)\b/i.test(note)) caveats.push(row[1].trim() + ': ' + note);
    }
    const report = { name: 'Storage Chest', unresolved: [], excluded: [], caveats, entries: titles.length };
    const results = await expand(titles);
    const items = collect(results, report);

    // Each object needs its quests: Bank Utilities' object_quests first, else the item infobox's quest links
    const known = Object.fromEntries([...fs.readFileSync('bankcleaner/data/object_quests.lua', 'utf8')
        .matchAll(/\[(\d+)\]=\{([\d,]*)\}/g)].map(match => [Number(match[1]), match[2].split(',').map(Number)]));
    const questRows = await api({ action: 'bucket',
        query: "bucket('infobox_quest').select('page_name','id').limit(5000).run()" });
    const questIDs = Object.fromEntries(questRows.bucket.map(row => [row.page_name, row.id]));
    const pageOf = {};
    for (const result of Object.values(results)) for (const item of result.items) {
        for (const id of item.rows.item_id || []) pageOf[id] = item.page;
    }
    const texts = await wikitexts([...new Set(Object.values(pageOf))]);
    report.questSources = { object_quests: 0, wiki: 0, none: 0 };
    report.agreement = { same: 0, different: [] };
    for (const item of items) {
        const page = pageOf[item.id];
        const names = new Set();
        for (const infobox of templates(texts[page] ? texts[page].text : '', 'Infobox Item')) {
            for (const line of infobox.split('\n')) {
                const field = line.match(/^\s*\|\s*quest\d*\s*=(.*)$/);
                if (field) for (const link of field[1].matchAll(/\[\[([^\]|#]+)/g)) names.add(link[1].trim());
            }
        }
        const wiki = [...names].filter(name => questIDs[name] !== undefined).map(name => questIDs[name]);
        if (known[item.id]) {
            item.quests = known[item.id];
            item.questNote = 'object_quests';
            report.questSources.object_quests++;
            if (wiki.length === 0) report.agreement.silent = (report.agreement.silent || 0) + 1;
            else if (known[item.id].every(id => wiki.includes(id))) report.agreement.same++;
            else report.agreement.different.push(`${item.id} ${item.name}: object_quests ${known[item.id].join(',')}`
                + `, infobox ${[...names].join(', ')}`);
        } else if (wiki.length > 0) {
            item.quests = [...new Set(wiki)].sort((a, b) => a - b);
            item.questNote = 'wiki: ' + [...names].filter(name => questIDs[name] !== undefined).join(', ');
            report.questSources.wiki++;
        } else {
            item.quests = [];
            report.questSources.none++;
            report.unresolved.push({ title: `${item.id} ${item.name}`, reason: 'no quest to confirm, so never shown' });
        }
    }
    return { report, items };
}

// Diango: every Table list block under Storable rewards, one section each
async function diango() {
    const text = await sourceText("Diango's Item Retrieval", 'Storable rewards');
    const body = text.split('<onlyinclude>')[1].split('</onlyinclude>')[0];
    const category = new Set(await categoryMembers(DIANGO_CATEGORY));
    category.name = DIANGO_CATEGORY;
    const sections = [];
    let heading = '';
    const tokens = body.split(/(^===[^=].*?===\s*$)/m);
    for (const token of tokens) {
        const headingMatch = token.match(/^===\s*(.*?)\s*===\s*$/);
        if (headingMatch) { heading = headingMatch[1]; continue; }
        for (const table of templates(token, 'Table list')) {
            const inner = table.replace(/^\{\{\s*Table list/i, '').replace(/\}\}$/, '').replace(/<!--[^]*?-->/g, '');
            let header = '';
            const entries = [];
            for (let part of inner.split('|')) {
                part = part.trim();
                if (part === '') continue;
                const parameter = part.match(/^(header|delimiter|columns|highlight|sort)\s*=\s*(.*)$/s);
                if (parameter) {
                    if (parameter[1] === 'header') header = parameter[2].trim();
                    continue;
                }
                const fields = part.split(';').map(field => field.trim());
                let name = fields[0].replace(/:pic=.*$/, '').trim();
                const named = {};
                for (const field of fields.slice(1)) {
                    const keyed = field.match(/^(pic|plink|text|tlink|ref):(.*)$/s);
                    if (keyed) named[keyed[1]] = keyed[2].trim();
                }
                const target = named.tlink || named.plink || name;
                entries.push({ name: named.text || name, target, fee: /fee3/.test(part) });
            }
            sections.push({ heading, header, entries });
        }
    }
    // A repeated header is told apart by its heading
    const counts = {};
    for (const section of sections) counts[section.header] = (counts[section.header] || 0) + 1;
    sections.forEach((section, index) => {
        section.id = 's' + String(index + 1).padStart(2, '0');
        section.label = counts[section.header] > 1 && section.heading !== section.header
            ? `${section.header} (${section.heading})` : section.header;
    });
    const titles = sections.flatMap(section => section.entries.map(entry => entry.target));
    const results = await expand(titles, { reclaim: { category, word: 'Diango' } });
    const report = { name: "Diango's Item Retrieval", unresolved: [], excluded: [], caveats: [], entries: titles.length,
        sections: [] };
    const objects = new Map();
    const duplicates = [];
    for (const section of sections) {
        const sectionResults = {};
        for (const entry of section.entries) sectionResults[entry.target] = results[entry.target];
        const sectionReport = { unresolved: [], excluded: [] };
        const items = collect(sectionResults, sectionReport);
        report.unresolved.push(...sectionReport.unresolved.map(item => ({ ...item, section: section.label })));
        report.excluded.push(...sectionReport.excluded.map(item => ({ ...item, section: section.label })));
        let added = 0;
        for (const item of items) {
            if (objects.has(item.id)) {
                if (objects.get(item.id).section !== section.id) duplicates.push({ id: item.id, name: item.name,
                    kept: objects.get(item.id).label, also: section.label });
                continue;
            }
            objects.set(item.id, { ...item, section: section.id, label: section.label });
            added++;
        }
        report.sections.push({ id: section.id, label: section.label, entries: section.entries.length,
            fees: section.entries.filter(entry => entry.fee).length, objects: added });
    }
    report.duplicates = duplicates;
    report.lists = Object.entries(results).filter(([, result]) => result.method === 'list' || result.method === 'pet')
        .map(([title, result]) => ({ title, method: result.method,
            names: [...new Set(result.items.map(item => rowName(item.rows)))] }));
    report.categoryMembers = category.size;
    return { report, sections, objects: [...objects.values()] };
}

// Return the plink targets in a navbox's Animals group
function animalLinks(text, start, end) {
    const group = text.slice(text.indexOf(start), text.indexOf(end));
    return [...group.matchAll(/\{\{plink\|([^|}]+)/g)].map(match => match[1].trim());
}

// Storm barn: checked animal items from both farms' navboxes
async function stormBarn() {
    await sourceText('Player-owned farm', 'Animals');
    await sourceText('Storm barn');
    const manorText = await sourceText('Template:Player-owned farm');
    const ranchText = await sourceText('Template:Anachronia Dinosaur Farm');
    const groups = [
        { id: 'manor', label: 'Manor Farm', titles: animalLinks(manorText, '|gtitle3 = [[Animals]]', '|gtitle4 = Items') },
        { id: 'anachronia', label: 'Anachronia Dinosaur Farm',
            titles: animalLinks(ranchText, '|gtitle3 = [[Animals]]', '|gtitle4 = Produce') },
    ];
    const report = { name: 'Storm barn', unresolved: [], excluded: [], caveats: [], entries: 0, sections: [] };
    const objects = new Map();
    for (const group of groups) {
        const unchecked = group.titles.filter(title => /\((unchecked|tutorial)\)/i.test(title));
        for (const title of unchecked) report.excluded.push({ title, reason: 'unchecked animal; the barn takes checked only' });
        const titles = group.titles.filter(title => !unchecked.includes(title));
        report.entries += titles.length;
        const sectionReport = { unresolved: [], excluded: [] };
        const items = collect(await expand(titles), sectionReport, name => !/\((unchecked|tutorial)\)/i.test(name));
        for (const item of sectionReport.unresolved) {
            report.excluded.push({ title: item.title,
                reason: 'no item of its own; as an item it appears as one of its normal breeds' });
        }
        report.excluded.push(...sectionReport.excluded);
        let added = 0;
        for (const item of items) {
            if (objects.has(item.id)) continue;
            objects.set(item.id, { ...item, section: group.id });
            added++;
        }
        report.sections.push({ id: group.id, label: group.label, entries: titles.length, objects: added });
    }
    // Cross-check: every checked animal item named "for your player owned farm"
    const search = await api({ action: 'query', list: 'search', srsearch: 'insource:"for your player owned farm"',
        srlimit: '500', srnamespace: '0' });
    const searched = search.query.search.map(result => result.title)
        .filter(title => !/\((unchecked|tutorial)\)/i.test(title));
    const searchedRows = await rowsByPage(searched);
    const known = new Set([...objects.keys()]);
    report.crossCheck = [];
    for (const [page, rows] of Object.entries(searchedRows)) {
        for (const row of rows) {
            if (/\((unchecked|tutorial)\)/i.test(row.item_name)) continue;
            for (const id of row.item_id || []) {
                if (!known.has(id)) report.crossCheck.push({ page, id, name: rowName(row) });
            }
        }
    }
    return { report, sections: groups.map(({ id, label }) => ({ id, label })), objects: [...objects.values()] };
}

// Archaeologist's workbench: the damaged artefacts its Products table restores
async function workbench() {
    const rendered = await renderedPage("Archaeologist's workbench");
    sources.push({ title: "Archaeologist's workbench", anchor: 'Products', revid: rendered.revid, rendered: true });
    const start = rendered.html.indexOf('id="Products"');
    const end = rendered.html.indexOf('<h2', start + 20);
    const table = rendered.html.slice(start, end === -1 ? undefined : end);
    const titles = [...new Set([...table.matchAll(/title="([^"]*\(damaged\))"/g)].map(match => decode(match[1])))];
    const products = (table.match(/<tr><td class="plainlist" data-sort-value/g) || []).length;
    const report = { name: "Archaeologist's workbench", unresolved: [], excluded: [], caveats: [], entries: titles.length,
        products };
    const items = collect(await expand(titles), report, name => /\(damaged\)/i.test(name));
    return { report, items };
}

// Material storage: the main List of materials table, not the tutorial-only table
async function materials() {
    const text = await sourceText('Materials (Archaeology)', 'List of materials');
    const main = text.slice(text.indexOf('==List of materials=='), text.indexOf('===Tutorial only==='));
    const tutorial = text.slice(text.indexOf('===Tutorial only==='), text.indexOf('{{Archaeology materials}}'));
    const titles = [...main.matchAll(/\{\{plinkt\|([^|}]+)/g)].map(match => match[1].trim());
    const report = { name: 'Materials (Archaeology)', unresolved: [], excluded: [], caveats: [], entries: titles.length };
    for (const match of tutorial.matchAll(/\{\{plinkt\|([^|}]+)/g)) {
        report.excluded.push({ title: match[1].trim(), reason: 'tutorial only; not storable' });
    }
    const results = await expand(titles);
    for (const [title, result] of Object.entries(results)) {
        if (result.items.length > 1) report.caveats.push(`${title}: ${result.items.length} item rows`);
    }
    const items = collect(results, report);
    return { report, items };
}

// Sort items by ID, dropping repeats
function uniqueItems(items) {
    const byID = new Map();
    for (const item of items) if (!byID.has(item.id)) byID.set(item.id, item);
    return [...byID.values()].sort((a, b) => a.id - b.id);
}

// Quote a Lua string
const lua = text => '"' + String(text).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"';
// Keep comments on one line
const comment = text => String(text).replace(/[\r\n]+/g, ' ');

// Write a { [id] = true } catalog
function writeSet(file, title, items) {
    const lines = [`-- ${title}`, '-- Generated by tools/catalogs/generate_catalogs.mjs; see docs/CATALOG_SOURCES.md', 'return {'];
    for (const item of uniqueItems(items)) lines.push(`    [${item.id}] = true, -- ${comment(item.name)}`);
    lines.push('}', '');
    fs.writeFileSync(file, lines.join('\n'));
}

// Write a { [id] = { questID, ... } } catalog; an empty list is never confirmed
function writeQuests(file, title, items) {
    const lines = [`-- ${title}`, '-- Generated by tools/catalogs/generate_catalogs.mjs; see docs/CATALOG_SOURCES.md', 'return {'];
    for (const item of uniqueItems(items)) {
        lines.push(`    [${item.id}] = { ${item.quests.join(', ')} }, -- ${comment(item.name)}`
            + ` (${item.questNote || 'no quest found'})`);
    }
    lines.push('}', '');
    fs.writeFileSync(file, lines.join('\n'));
}

// Write a { sections = {...}, objects = { [id] = section } } catalog
function writeSections(file, title, sections, items) {
    const lines = [`-- ${title}`, '-- Generated by tools/catalogs/generate_catalogs.mjs; see docs/CATALOG_SOURCES.md', 'return {',
        '    sections = {'];
    for (const section of sections) lines.push(`        { id = ${lua(section.id)}, label = ${lua(section.label)} },`);
    lines.push('    },', '    objects = {');
    for (const item of [...items].sort((a, b) => a.id - b.id)) {
        lines.push(`        [${item.id}] = ${lua(item.section)}, -- ${comment(item.name)}`);
    }
    lines.push('    },', '}', '');
    fs.writeFileSync(file, lines.join('\n'));
}

// List report problems as markdown bullets
function problems(report) {
    const lines = [];
    const unresolved = report.unresolved || [];
    const excluded = report.excluded || [];
    lines.push(`- Unresolved entries: ${unresolved.length}`);
    for (const item of unresolved) lines.push(`  - ${item.title}${item.section ? ` (${item.section})` : ''}: ${item.reason}`);
    lines.push(`- Excluded: ${excluded.length}`);
    for (const item of excluded) {
        lines.push(`  - ${item.title}${item.name && item.name !== item.title ? ` → ${item.name}` : ''}`
            + `${item.section ? ` (${item.section})` : ''}: ${item.reason}`);
    }
    if (report.caveats && report.caveats.length > 0) {
        lines.push(`- Notes: ${report.caveats.length}`);
        for (const caveat of report.caveats) lines.push(`  - ${caveat}`);
    }
    return lines;
}

const chest = await storageChest();
const diangoData = await diango();
const barn = await stormBarn();
const bench = await workbench();
const mats = await materials();

writeQuests('bankcleaner/data/storage_chest_objects.lua',
    "Items May's Storage Chest can return, with the quests that must be finished first", chest.items);
writeSections('bankcleaner/data/diango_objects.lua', "Items Diango's Item Retrieval can return, by wiki table",
    diangoData.sections.map(({ id, label }) => ({ id, label })), diangoData.objects);
writeSections('bankcleaner/data/storm_barn_objects.lua', 'Checked farm animals the storm barn stores, by farm',
    barn.sections, barn.objects);
writeSet('bankcleaner/data/workbench_artefact_objects.lua', "Damaged artefacts an archaeologist's workbench stores",
    bench.items);
writeSet('bankcleaner/data/material_storage_objects.lua', 'Archaeology materials the material storage container holds',
    mats.items);

const doc = [
    '# Catalog sources',
    '',
    `Generated ${today} by \`node tools/catalogs/generate_catalogs.mjs\` from the RuneScape Wiki's public API`
        + ' (`action=query` revisions, `action=parse` for rendered tables, and the `infobox_item` bucket for item IDs).'
        + ' Item IDs come only from item infoboxes: an entry naming a set (an `Infobox Set`) lists its pieces,'
        + ' and an entry naming neither is listed as unresolved rather than guessed.',
    '',
    '## Source revisions',
    '',
    '| Page | Section | Revision |',
    '| --- | --- | --- |',
    ...sources.map(source => `| [${source.title}](${pageURL(source.title)}${source.anchor ? '#' + source.anchor.replace(/ /g, '_') : ''})`
        + ` | ${source.anchor || ''}${source.rendered ? ' (rendered)' : ''} | ${source.revid}${source.timestamp ? ' (' + source.timestamp + ')' : ''} |`),
    '',
    '## Storage Chest',
    '',
    `\`storage_chest_objects.lua\`: ${uniqueItems(chest.items).length} objects from ${chest.report.entries} named items`
        + ' (each table row, plus an alternative it names, such as the engrammeter or the ring of charos (a)).'
        + ' The wiki lists only reclaimable items. Each object carries the quests that must be confirmed finished'
        + ' before it shows: Bank Utilities\' `object_quests` when it has the object'
        + ` (${chest.report.questSources.object_quests}), otherwise the quest links in the item's infobox mapped to quest`
        + ` IDs through the \`infobox_quest\` bucket (${chest.report.questSources.wiki}); an object with neither`
        + ` (${chest.report.questSources.none}) is listed with no quests and never shows.`
        + ` Of the objects \`object_quests\` covers, the infobox links every one of its quests for`
        + ` ${chest.report.agreement.same}, links no quest for ${chest.report.agreement.silent || 0}, and conflicts for`
        + ` ${chest.report.agreement.different.length}.`
        + ' The chest is members only and needs 150 quest points allocated to the caravan\'s Hub Track.',
    '',
    ...chest.report.agreement.different.map(note => `- Differs: ${note}`),
    ...problems(chest.report),
    '',
    "## Diango's Item Retrieval",
    '',
    `\`diango_objects.lua\`: ${diangoData.objects.length} objects in ${diangoData.sections.length} sections, one per wiki`
        + ` table, from ${diangoData.report.entries} entries. An entry naming a set (\`Infobox Set\`) or a list page`
        + ' (such as an outfit whose page lists its pieces, keeping only linked item pages that link back) counts a'
        + ` piece only when the piece's page is in [${DIANGO_CATEGORY}](${pageURL(DIANGO_CATEGORY)})`
        + ` (${diangoData.report.categoryMembers} pages) or names Diango; a pet entry uses its pet infobox's item ID.`
        + ' An object in several tables is shown in the first. Fees: the wiki marks some entries "Requires return fee", and items with'
        + ' combat stats above tier 1 cost a fee to reclaim; several outfits are reclaimable only if not combined or'
        + ' upgraded, and add-ons only if not installed.',
    '',
    '| Section | Entries | Fee entries | Objects |',
    '| --- | --- | --- | --- |',
    ...diangoData.report.sections.map(section => `| ${section.label} | ${section.entries} | ${section.fees} | ${section.objects} |`),
    '',
    `- Objects also in a later table: ${diangoData.report.duplicates.length}`,
    ...diangoData.report.duplicates.map(item => `  - ${item.id} ${item.name}: shown in ${item.kept}, also ${item.also}`),
    `- Entries read from a list or pet page: ${diangoData.report.lists.length}`,
    ...diangoData.report.lists.map(item => `  - ${item.title} (${item.method}): ${item.names.join(', ') || 'nothing'}`),
    ...problems(diangoData.report),
    '',
    '## Storm barn',
    '',
    `\`storm_barn_objects.lua\`: ${barn.objects.length} checked animal items from the Animals groups of the Player-owned`
        + ' farm and Anachronia Dinosaur Farm navboxes. The barn stores checked animals only, so unchecked and tutorial'
        + ' animals are left out; eggs and babies are growth stages of the checked item, and shiny breeds without'
        + ' their own item show as their base breed. Produce, pets, and unchecked eggs are not listed.',
    '',
    '| Section | Entries | Objects |',
    '| --- | --- | --- |',
    ...barn.report.sections.map(section => `| ${section.label} | ${section.entries} | ${section.objects} |`),
    '',
    `- Checked animal items found by the wiki search \`insource:"for your player owned farm"\` but not in a navbox: ${barn.report.crossCheck.length}`,
    ...barn.report.crossCheck.map(item => `  - ${item.id} ${item.name} (${item.page})`),
    ...problems(barn.report),
    '',
    "## Archaeologist's workbench",
    '',
    `\`workbench_artefact_objects.lua\`: ${uniqueItems(bench.items).length} objects from ${bench.report.entries} damaged`
        + ` artefacts in the rendered Products table (${bench.report.products} products). Only the damaged artefacts`
        + ' count; restored artefacts and materials do not. Storage needs a workbench upgrade from the Archaeology'
        + ' Guild Shop.',
    '',
    ...problems(bench.report),
    '',
    '## Material storage',
    '',
    `\`material_storage_objects.lua\`: ${uniqueItems(mats.items).length} objects from the ${mats.report.entries}`
        + ' materials in the List of materials table; the tutorial-only table is left out.',
    '',
    ...problems(mats.report),
    '',
];
fs.writeFileSync('docs/CATALOG_SOURCES.md', doc.join('\n'));
console.log(JSON.stringify({
    chest: uniqueItems(chest.items).length, chestUnresolved: chest.report.unresolved.length,
    diango: diangoData.objects.length, diangoSections: diangoData.sections.length,
    diangoUnresolved: diangoData.report.unresolved.length, diangoExcluded: diangoData.report.excluded.length,
    barn: barn.objects.length, barnCross: barn.report.crossCheck.length,
    bench: uniqueItems(bench.items).length, benchUnresolved: bench.report.unresolved.length,
    materials: uniqueItems(mats.items).length, materialsUnresolved: mats.report.unresolved.length,
}));
