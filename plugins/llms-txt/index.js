// @ts-check
const fs = require('fs');
const path = require('path');

/**
 * Build-time generator for llms.txt and llms-full.txt.
 *
 * - llms.txt:      a curated, single-fetch index of every docs page (title +
 *                  one-line description + canonical URL), grouped by the sidebar
 *                  structure, per the convention at https://llmstxt.org.
 * - llms-full.txt: the full text of every docs page concatenated into one file,
 *                  each section prefixed with its title and canonical URL.
 *
 * Both files are derived from the Markdown sources at build time so they never
 * drift from the published content. They are written into the build output
 * (and served at /llms.txt and /llms-full.txt).
 *
 * @param {import('@docusaurus/types').LoadContext} context
 * @returns {import('@docusaurus/types').Plugin}
 */
module.exports = function llmsTxtPlugin(context) {
  const { siteDir, siteConfig } = context;

  return {
    name: 'llms-txt',

    async postBuild({ outDir }) {
      const docsDir = path.join(siteDir, 'docs');
      // Canonical site origin, e.g. "https://docs.zkcoins.com" (no trailing slash).
      const origin = (siteConfig.url + siteConfig.baseUrl).replace(/\/+$/, '');

      // --- helpers -----------------------------------------------------------

      /** Recursively collect all Markdown files under docsDir (posix-relative). */
      const collect = (dir) => {
        /** @type {string[]} */
        const out = [];
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const abs = path.join(dir, entry.name);
          if (entry.isDirectory()) out.push(...collect(abs));
          else if (/\.mdx?$/.test(entry.name)) out.push(abs);
        }
        return out;
      };

      /** Split a Markdown file into { data: frontmatter, body }. */
      const parse = (raw) => {
        const m = raw.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
        if (!m) return { data: {}, body: raw };
        /** @type {Record<string,string>} */
        const data = {};
        for (const line of m[1].split(/\r?\n/)) {
          const kv = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
          if (kv) data[kv[1]] = kv[2].replace(/^["']|["']$/g, '').trim();
        }
        return { data, body: m[2] };
      };

      /** Map a docs-relative path + frontmatter to a site-absolute route. */
      const routeOf = (rel, data) => {
        const id = rel.replace(/\\/g, '/').replace(/\.mdx?$/, '');
        if (data.slug) {
          if (data.slug === '/') return '/';
          if (data.slug.startsWith('/')) return data.slug.replace(/\/+$/, '') || '/';
          const dir = id.includes('/') ? id.slice(0, id.lastIndexOf('/') + 1) : '';
          return '/' + dir + data.slug.replace(/^\/+/, '');
        }
        const segs = id.split('/');
        const last = segs[segs.length - 1].toLowerCase();
        if (last === 'index' || last === 'readme') {
          segs.pop();
          return '/' + (segs.length ? segs.join('/') + '/' : '');
        }
        return '/' + id;
      };

      /** First H1 text, if any. */
      const firstH1 = (body) => {
        const m = body.match(/^#\s+(.+?)\s*$/m);
        return m ? m[1].trim() : '';
      };

      /** Turn a docs id into a Title Case fallback label. */
      const humanize = (id) =>
        id
          .split('/')
          .pop()
          .replace(/[-_]/g, ' ')
          .replace(/\b\w/g, (c) => c.toUpperCase());

      /** Strip Markdown to a clean one-line description. */
      const describe = (data, body) => {
        if (data.description) return data.description.trim();
        const lines = body.split(/\r?\n/);
        let para = '';
        let inAdmonition = false;
        for (const lineRaw of lines) {
          const line = lineRaw.trim();
          if (!line) {
            if (para) break;
            continue;
          }
          if (line.startsWith(':::')) {
            inAdmonition = !inAdmonition;
            continue;
          }
          if (inAdmonition) continue;
          if (line.startsWith('#')) continue; // headings
          if (line.startsWith('import ') || line.startsWith('export ')) continue;
          if (/^[-*|>]/.test(line) || line.startsWith('```')) {
            if (para) break;
            continue; // skip lists/tables/quotes/code as the lead sentence
          }
          para += (para ? ' ' : '') + line;
          if (para.length > 160) break;
        }
        // Clean inline Markdown.
        let text = para
          .replace(/\[!\w+\]/g, '')
          .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1') // links → text
          .replace(/[*_`]+/g, '')
          .replace(/\s+/g, ' ')
          .trim();
        if (text.length > 200) {
          text = text.slice(0, 200).replace(/\s+\S*$/, '') + '…';
        }
        return text;
      };

      // --- load every page ---------------------------------------------------

      /** @type {Map<string, {title:string, url:string, desc:string, body:string}>} */
      const byId = new Map();
      for (const abs of collect(docsDir)) {
        const rel = path.relative(docsDir, abs).replace(/\\/g, '/');
        const { data, body } = parse(fs.readFileSync(abs, 'utf8'));
        const id = rel.replace(/\.mdx?$/, '');
        byId.set(id, {
          title: data.title || firstH1(body) || humanize(id),
          url: origin + routeOf(rel, data),
          desc: describe(data, body),
          body: body.trim(),
        });
      }

      // --- order by the sidebar ---------------------------------------------

      const sidebars = require(path.join(siteDir, 'sidebars.js'));
      const tree = (sidebars.docs || []);

      /** @type {string[]} */
      const guides = []; // top-level standalone pages (excluding intro)
      /** @type {{label:string, ids:string[]}[]} */
      const categories = [];
      let intro = null;

      for (const node of tree) {
        if (typeof node === 'string') {
          if (node === 'intro') intro = node;
          else guides.push(node);
        } else if (node && node.type === 'category') {
          categories.push({
            label: node.label,
            ids: (node.items || []).filter((i) => typeof i === 'string'),
          });
        }
      }

      const listItem = (id) => {
        const p = byId.get(id);
        if (!p) return null;
        return `- [${p.title}](${p.url})${p.desc ? `: ${p.desc}` : ''}`;
      };

      // --- assemble llms.txt -------------------------------------------------

      const lines = [];
      lines.push(`# ${siteConfig.title}`);
      lines.push('');
      if (siteConfig.tagline) {
        lines.push(`> ${siteConfig.tagline}`);
        lines.push('');
      }
      if (intro && byId.get(intro)?.desc) {
        lines.push(byId.get(intro).desc);
        lines.push('');
      }

      if (guides.length) {
        lines.push('## Guides');
        for (const id of guides) {
          const li = listItem(id);
          if (li) lines.push(li);
        }
        lines.push('');
      }

      for (const cat of categories) {
        const items = cat.ids.map(listItem).filter(Boolean);
        if (!items.length) continue;
        lines.push(`## ${cat.label}`);
        lines.push(...items);
        lines.push('');
      }

      lines.push('## Full text');
      lines.push(
        `- [llms-full.txt](${origin}/llms-full.txt): the complete documentation concatenated into a single file.`,
      );
      lines.push('');

      const llmsTxt = lines.join('\n');

      // --- assemble llms-full.txt -------------------------------------------

      const orderedIds = [
        ...(intro ? [intro] : []),
        ...guides,
        ...categories.flatMap((c) => c.ids),
      ];
      // Append any pages not referenced by the sidebar, so nothing is dropped.
      for (const id of byId.keys()) {
        if (!orderedIds.includes(id)) orderedIds.push(id);
      }

      const full = [`# ${siteConfig.title} — full documentation`, ''];
      if (siteConfig.tagline) full.push(`> ${siteConfig.tagline}`, '');
      for (const id of orderedIds) {
        const p = byId.get(id);
        if (!p) continue;
        full.push('---', '', `# ${p.title}`, '', `Source: ${p.url}`, '', p.body, '');
      }
      const llmsFull = full.join('\n');

      // --- write -------------------------------------------------------------

      fs.writeFileSync(path.join(outDir, 'llms.txt'), llmsTxt + '\n', 'utf8');
      fs.writeFileSync(path.join(outDir, 'llms-full.txt'), llmsFull + '\n', 'utf8');
    },
  };
};
