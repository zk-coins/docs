/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
        'architecture/information-model',
        'architecture/information-flow',
        'architecture/trust-model',
        'architecture/privacy-model',
        'architecture/nullifier-design',
        'architecture/transaction-flow',
        'architecture/key-management',
        'architecture/signup-flow',
        'architecture/proof-system',
        'architecture/addressing',
        'architecture/aliasing',
        'architecture/bridging',
      ],
    },
    'protocol',
    'wallet',
    {
      type: 'category',
      label: 'Infrastructure',
      items: ['infrastructure/backend', 'infrastructure/deployment'],
    },
    'comparisons',
    'tech-decisions',
    {
      type: 'category',
      label: 'Research',
      items: [
        'research/index',
        'research/protocol-analysis',
        'research/authors',
        'research/community',
        'research/sources',
        {
          type: 'category',
          label: 'Adoptable Elements',
          items: [
            'research/adoptable-elements/index',
            'research/adoptable-elements/csv-bitcoin',
            'research/adoptable-elements/shielded-zk-chains',
            'research/adoptable-elements/evm-privacy',
            'research/adoptable-elements/stateless-rollups',
            'research/adoptable-elements/bitcoin-asset-overlays',
            'research/adoptable-elements/ecash',
            'research/adoptable-elements/other-trust-models',
          ],
        },
      ],
    },
    'risks',
  ],
};

module.exports = sidebars;
