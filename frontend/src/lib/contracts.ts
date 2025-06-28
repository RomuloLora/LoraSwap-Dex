// Contract addresses (updated after deployment)
export const CONTRACT_ADDRESSES = {
  factory: "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512",
  router: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0",
  loraToken: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
  loraToken2: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
} as const;

// Basic utility functions
export const formatTokenAmount = (amount: string, decimals: number = 18): string => {
  return amount;
};

export const parseTokenAmount = (amount: string, decimals: number = 18): string => {
  return amount;
};

export const getContractAddress = (contractName: keyof typeof CONTRACT_ADDRESSES) => {
  return CONTRACT_ADDRESSES[contractName];
}; 