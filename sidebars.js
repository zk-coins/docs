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
        'architecture/signup-flow',
        'architecture/proof-system',
        'architecture/addressing',
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
      ],
    },
    'risks',
  ],
};

module.exports = sidebars;
