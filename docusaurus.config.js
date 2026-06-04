// @ts-check

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'zkCoins Docs',
  tagline: 'Private Bitcoin Transactions via Shielded CSV',
  favicon: 'img/favicon.svg',

  url: 'https://docs.zkcoins.app',
  baseUrl: '/',

  organizationName: 'zk-coins',
  projectName: 'zkcoins-app',

  onBrokenLinks: 'throw',
  onBrokenMarkdownLinks: 'warn',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      colorMode: {
        defaultMode: 'dark',
        disableSwitch: false,
        respectPrefersColorScheme: false,
      },
      navbar: {
        title: 'zkCoins',
        items: [
          {
            href: 'https://zkcoins.app',
            label: 'Wallet',
            position: 'right',
          },
          {
            href: 'https://github.com/zk-coins',
            label: 'GitHub',
            position: 'right',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Documentation',
            items: [
              { label: 'Introduction', to: '/' },
              { label: 'Architecture', to: '/architecture/overview' },
              { label: 'Protocol', to: '/protocol' },
              { label: 'Wallet', to: '/wallet' },
            ],
          },
          {
            title: 'Source Code',
            items: [
              {
                label: 'Monorepo',
                href: 'https://github.com/zk-coins/zkcoins-app',
              },
              {
                label: 'Rust Backend',
                href: 'https://github.com/zk-coins/zkcoins-app/tree/develop/rust/server',
              },
              {
                label: 'WASM Client',
                href: 'https://github.com/zk-coins/zkcoins-app/tree/develop/rust/client',
              },
              {
                label: 'Plonky2 Circuit',
                href: 'https://github.com/zk-coins/node/tree/develop/program-plonky2',
              },
            ],
          },
          {
            title: 'Protocol',
            items: [
              {
                label: 'Shielded CSV Paper',
                href: 'https://eprint.iacr.org/2025/068',
              },
              {
                label: 'ZeroSync Prototype',
                href: 'https://github.com/ZeroSync/ZKCoins',
              },
              {
                label: 'shieldedcsv.org',
                href: 'https://shieldedcsv.org',
              },
            ],
          },
        ],
        copyright: `Copyright ${new Date().getFullYear()} zkCoins.`,
      },
      prism: {
        additionalLanguages: ['rust', 'bash', 'json', 'toml'],
      },
    }),
};

module.exports = config;
