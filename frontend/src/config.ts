export const CONTRACT_ADDRESSES = {
  akmenaCore: '0x0C4710331d6e234fE311C1c27252Ad63b7A6ac99',
  escrowEngine: '0x18FdA79e236E303d6de1Bf94a12E5137d45E3D84',
  policyBoundary: '0xdC3fC3e840b14Ce345638549D0d4617b75cD89b9',
  privacyEngine: '0x7e5095d10a4B71220938b816398918239981030a',
  defaultAiAgent: '0xC72CBbeaf7F540522804BcbF592dc7a6b6906476', // Your AI Agent recipient
  // Derived at runtime from AkmenaPolicyBoundary.executionAuthorization().
};

export const NETWORK_CONFIG = {
  chainId: 84532,
  chainName: 'Base Sepolia',
  rpcUrl: 'https://sepolia.base.org',
  blockExplorer: 'https://sepolia.basescan.org',
};
