/** @type {import('@docusaurus/plugin-content-docs').SidebarsConfig} */
const sidebars = {
  docs: [
    'intro',
    'requirements',
    'specification',
    'implementation-mandate',
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
    'comparisons',
    'tech-decisions',
    'roadmap',
    'risks',
  ],
};

module.exports = sidebars;
