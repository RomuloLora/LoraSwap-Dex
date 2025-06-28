const fs = require('fs');
const path = require('path');

// Function to update contract addresses in the frontend
function updateContractAddresses(deploymentData) {
  const contractsPath = path.join(__dirname, '../src/lib/contracts.ts');
  
  // Read the current contracts file
  let contractsContent = fs.readFileSync(contractsPath, 'utf8');
  
  // Update the contract addresses
  contractsContent = contractsContent.replace(
    /factory: "0x0000000000000000000000000000000000000000"/,
    `factory: "${deploymentData.factory}"`
  );
  
  contractsContent = contractsContent.replace(
    /router: "0x0000000000000000000000000000000000000000"/,
    `router: "${deploymentData.router}"`
  );
  
  contractsContent = contractsContent.replace(
    /loraToken: "0x0000000000000000000000000000000000000000"/,
    `loraToken: "${deploymentData.loraToken}"`
  );
  
  contractsContent = contractsContent.replace(
    /loraToken2: "0x0000000000000000000000000000000000000000"/,
    `loraToken2: "${deploymentData.loraToken2}"`
  );
  
  // Write the updated content back
  fs.writeFileSync(contractsPath, contractsContent);
  
  console.log('✅ Contract addresses updated in frontend');
}

// Function to create environment file
function createEnvFile(deploymentData) {
  const envContent = `# Contract Addresses
NEXT_PUBLIC_FACTORY_ADDRESS=${deploymentData.factory}
NEXT_PUBLIC_ROUTER_ADDRESS=${deploymentData.router}
NEXT_PUBLIC_LORA_TOKEN_ADDRESS=${deploymentData.loraToken}
NEXT_PUBLIC_LORA_TOKEN2_ADDRESS=${deploymentData.loraToken2}

# Network Configuration
NEXT_PUBLIC_CHAIN_ID=31337
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545

# WalletConnect
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id_here
`;

  const envPath = path.join(__dirname, '../.env.local');
  fs.writeFileSync(envPath, envContent);
  
  console.log('✅ Environment file created');
}

// Main function
function main() {
  // This would typically come from the deployment output
  // For now, we'll use placeholder addresses
  const deploymentData = {
    factory: process.env.FACTORY_ADDRESS || '0x0000000000000000000000000000000000000000',
    router: process.env.ROUTER_ADDRESS || '0x0000000000000000000000000000000000000000',
    loraToken: process.env.LORA_TOKEN_ADDRESS || '0x0000000000000000000000000000000000000000',
    loraToken2: process.env.LORA_TOKEN2_ADDRESS || '0x0000000000000000000000000000000000000000',
  };
  
  console.log('🚀 Updating frontend with contract addresses...');
  console.log('Deployment data:', deploymentData);
  
  try {
    updateContractAddresses(deploymentData);
    createEnvFile(deploymentData);
    console.log('✅ Frontend deployment script completed successfully!');
  } catch (error) {
    console.error('❌ Error updating frontend:', error);
    process.exit(1);
  }
}

// Run the script
if (require.main === module) {
  main();
}

module.exports = { updateContractAddresses, createEnvFile }; 