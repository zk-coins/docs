/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    {
      type: 'category',
      label: 'Architecture',
      items: [
        'architecture/overview',
        'architecture/privacy-model',
        'architecture/nullifier-design',
        'architecture/transaction-flow',
        'architecture/key-management',
        'architecture/proof-system',
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
    'risks',
  ],
};

module.exports = sidebars;
