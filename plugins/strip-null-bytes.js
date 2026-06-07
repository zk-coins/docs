const fs = require('fs');
const path = require('path');

// Docusaurus 3.9's SSR HTML serializer can emit stray NUL (0x00) bytes next to
// some multibyte glyphs (e.g. "—", "↔", "─"). Browsers drop in-body NULs, so
// pages render and deep-link anchors resolve, but the NULs make the emitted
// files classify as binary (grep, some crawlers/indexers, `file`). This plugin
// strips them from the generated HTML after the build so the output is valid
// text/html. Pure post-processing; the source markdown is already NUL-free.
module.exports = function stripNullBytes() {
  return {
    name: 'strip-null-bytes',
    async postBuild({ outDir }) {
      const walk = (dir) => {
        for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
          const p = path.join(dir, entry.name);
          if (entry.isDirectory()) walk(p);
          else if (entry.name.endsWith('.html')) {
            const buf = fs.readFileSync(p);
            if (buf.includes(0)) {
              fs.writeFileSync(p, Buffer.from(buf.filter((b) => b !== 0)));
            }
          }
        }
      };
      walk(outDir);
    },
  };
};
