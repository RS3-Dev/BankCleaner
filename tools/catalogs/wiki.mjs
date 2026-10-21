// Read the RuneScape Wiki's public API, saving every response for audit
// Node only; run by tools/catalogs/generate_catalogs.mjs, never by the plugin

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

const API = 'https://runescape.wiki/api.php';
const CACHE = process.env.WIKI_CACHE || path.join(os.tmpdir(), 'bankcleaner-wiki-cache');
fs.mkdirSync(CACHE, { recursive: true });

// Fetch one API call, or read the saved response
export async function api(params) {
    const search = new URLSearchParams({ format: 'json', ...params });
    const key = crypto.createHash('sha1').update(search.toString()).digest('hex').slice(0, 16);
    const file = path.join(CACHE, key + '.json');
    if (fs.existsSync(file)) return JSON.parse(fs.readFileSync(file, 'utf8')).response;
    for (let attempt = 0; attempt < 4; attempt++) {
        const response = await fetch(API + '?' + search, {
            headers: { 'User-Agent': 'BankCleanerCatalog/1.0 (storage catalog audit)' },
        });
        if (response.ok) {
            const json = await response.json();
            fs.writeFileSync(file, JSON.stringify({
                url: API + '?' + search.toString(), fetched: new Date().toISOString(), response: json,
            }));
            return json;
        }
        await new Promise(resolve => setTimeout(resolve, 1500 * (attempt + 1)));
    }
    throw new Error('wiki request failed: ' + search);
}

// Quote text as a Lua string for a bucket query
const luaString = text => "'" + text.replace(/\\/g, '\\\\').replace(/'/g, "\\'") + "'";

// Read infobox_item rows for pages, 40 pages per query
export async function itemRows(pages) {
    const rows = [];
    for (let index = 0; index < pages.length; index += 40) {
        const chunk = pages.slice(index, index + 40);
        const where = chunk.length === 1
            ? `.where('page_name',${luaString(chunk[0])})`
            : `.where(bucket.Or(${chunk.map(page => `{'page_name',${luaString(page)}}`).join(',')}))`;
        const query = "bucket('infobox_item').select('item_name','item_id','page_name','page_name_sub')"
            + where + '.limit(5000).run()';
        const result = await api({ action: 'bucket', query });
        if (result.error) throw new Error(JSON.stringify(result.error));
        rows.push(...result.bucket);
    }
    return rows;
}

// Follow redirects; missing pages map to null, a section redirect keeps its page
export async function resolveTitles(titles) {
    const resolved = {};
    const unique = [...new Set(titles)];
    for (let index = 0; index < unique.length; index += 50) {
        const chunk = unique.slice(index, index + 50);
        const result = await api({ action: 'query', titles: chunk.join('|'), redirects: '1' });
        const normalized = Object.fromEntries((result.query.normalized || []).map(entry => [entry.from, entry.to]));
        const redirects = Object.fromEntries((result.query.redirects || []).map(entry => [entry.from, entry.to]));
        const missing = new Set(Object.values(result.query.pages)
            .filter(page => page.missing !== undefined || page.invalid !== undefined).map(page => page.title));
        for (const title of chunk) {
            let target = normalized[title] || title;
            target = redirects[target] || target;
            resolved[title] = missing.has(target) ? null : target;
        }
    }
    return resolved;
}

// Read pages' current wikitext and revision IDs, 50 at a time
export async function wikitexts(titles) {
    const pages = {};
    const unique = [...new Set(titles)];
    for (let index = 0; index < unique.length; index += 50) {
        const chunk = unique.slice(index, index + 50);
        const result = await api({
            action: 'query', prop: 'revisions', rvprop: 'content|ids|timestamp', rvslots: 'main',
            titles: chunk.join('|'),
        });
        for (const page of Object.values(result.query.pages)) {
            if (page.revisions) {
                const revision = page.revisions[0];
                pages[page.title] = { revid: revision.revid, timestamp: revision.timestamp, text: revision.slots.main['*'] };
            }
        }
    }
    return pages;
}

// List a category's article titles
export async function categoryMembers(category) {
    const titles = [];
    let next = {};
    while (next) {
        const result = await api({ action: 'query', list: 'categorymembers', cmtitle: category, cmlimit: '500', ...next });
        titles.push(...result.query.categorymembers.filter(member => member.ns === 0).map(member => member.title));
        next = result.continue || null;
    }
    return titles;
}

// List the article titles that link to a page
export async function backlinks(title) {
    const titles = [];
    let next = {};
    while (next) {
        const result = await api({ action: 'query', list: 'backlinks', bltitle: title, blnamespace: '0', bllimit: '500',
            ...next });
        titles.push(...result.query.backlinks.map(link => link.title));
        next = result.continue || null;
    }
    return titles;
}

// Render a page to HTML and return it with its revision ID
export async function renderedPage(title) {
    const result = await api({ action: 'parse', page: title, prop: 'text|revid' });
    return { revid: result.parse.revid, html: result.parse.text['*'] };
}
