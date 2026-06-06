// @ts-check
const fs = require('fs');
const path = require('path');

// The Cloudflare Pages production branch. Builds of this branch serve the
// canonical site (docs.zkcoins.app) and are left fully crawlable. Every other
// branch is a preview deployment (e.g. develop -> dev-docs.zkcoins.app).
const PROD_BRANCH = process.env.PROD_PAGES_BRANCH || 'main';

// AI crawlers that honour only their own named record (rather than the `*`
// group) are listed explicitly so the block applies to them too. Mirrors the
// allow-list in static/robots.txt, inverted to Disallow for previews.
const NAMED_AGENTS = [
  'ClaudeBot',
  'GPTBot',
  'Google-Extended',
  'CCBot',
  'Bytespider',
  'Amazonbot',
  'Applebot-Extended',
  'meta-externalagent',
];

/**
 * Keep preview (non-production) Cloudflare Pages deployments out of search and
 * AI indexes, while leaving the production site fully open via static/robots.txt.
 *
 * The single static/robots.txt is copied verbatim into every build, so it
 * cannot distinguish the production host (docs.zkcoins.app, built from `main`)
 * from a preview host (dev-docs.zkcoins.app, built from `develop`). This plugin
 * resolves that at build time: on a Cloudflare Pages build whose branch is not
 * the production branch, it overwrites the build output's robots.txt with a
 * Disallow-all (plus explicit AI-crawler records) and adds a _headers rule
 * sending `X-Robots-Tag: noindex, nofollow` for every path. Both files live
 * only in that deployment's output, so production is untouched.
 *
 * Outside Cloudflare Pages (local builds, CI without CF_PAGES), nothing changes
 * and the open static/robots.txt is served as-is.
 *
 * @returns {import('@docusaurus/types').Plugin}
 */
module.exports = function noindexPreviewPlugin() {
  return {
    name: 'noindex-preview',

    async postBuild({ outDir }) {
      const isPagesBuild = process.env.CF_PAGES === '1';
      const branch = process.env.CF_PAGES_BRANCH;
      if (!isPagesBuild || branch === PROD_BRANCH) return;

      const robots = [
        '# Preview deployment — NOT the canonical site.',
        `# Built from branch "${branch || 'unknown'}" (production branch is "${PROD_BRANCH}").`,
        '# The canonical, crawler-open site is https://docs.zkcoins.app.',
        '# Preview builds are excluded from search and AI indexes to avoid',
        '# duplicate-content indexing and crawling of unreleased drafts.',
        '',
        'User-agent: *',
        'Disallow: /',
        '',
        ...NAMED_AGENTS.flatMap((agent) => [`User-agent: ${agent}`, 'Disallow: /', '']),
      ].join('\n');
      fs.writeFileSync(path.join(outDir, 'robots.txt'), robots);

      // Cloudflare Pages _headers: applies the noindex header to this
      // deployment's output only. Prepend, preserving any existing file.
      const headersPath = path.join(outDir, '_headers');
      const rule = '/*\n  X-Robots-Tag: noindex, nofollow\n';
      const existing = fs.existsSync(headersPath)
        ? fs.readFileSync(headersPath, 'utf8')
        : '';
      fs.writeFileSync(headersPath, existing ? `${rule}\n${existing}` : rule);
    },
  };
};
