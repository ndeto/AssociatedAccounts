#!/usr/bin/env node

/**
 * Query controlled-accounts.ecs.eth on Ethereum Sepolia
 * 
 * Usage:
 *   node scripts/query-ens.js [id]
 * 
 * Examples:
 *   node scripts/query-ens.js        # Query ID 0
 *   node scripts/query-ens.js 1      # Query ID 1
 *   node scripts/query-ens.js info   # Query resolver-info
 */

import { createPublicClient, http, namehash } from 'viem';
import { sepolia } from 'viem/chains';
import yaml from 'js-yaml';

// Configuration
const ENS_NAME = 'controlled-accounts.ecs.eth';
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || 'https://ethereum-sepolia-rpc.publicnode.com';
const TEXT_RECORD_PREFIX = 'eth.ecs.controlled-accounts:';

// Create viem public client
const client = createPublicClient({
  chain: sepolia,
  transport: http(SEPOLIA_RPC_URL),
});

/**
 * Decode ERC-7930 Interoperable Address to Ethereum address
 * @param {string} hexAddress - Hex-encoded ERC-7930 address
 * @returns {object} Decoded address info
 */
function decodeERC7930Address(hexAddress) {
  // Remove 0x prefix if present
  const hex = hexAddress.replace('0x', '');
  
  // Parse ERC-7930 V1 format (from InteroperableAddresses.sol):
  // 2 bytes: version (0x0001)
  // 2 bytes: chainType (0x0000 = EIP-155/EVM)
  // 1 byte: chainReference length
  // variable bytes: chainReference (chain ID)
  // 1 byte: address length
  // variable bytes: address
  
  let offset = 0;
  
  // Read version (2 bytes = 4 hex chars)
  const version = '0x' + hex.substring(offset, offset + 4);
  offset += 4;
  
  // Read chainType (2 bytes = 4 hex chars)
  const chainType = '0x' + hex.substring(offset, offset + 4);
  offset += 4;
  
  // Read chainReference length (1 byte = 2 hex chars)
  const chainRefLength = parseInt(hex.substring(offset, offset + 2), 16);
  offset += 2;
  
  // Read chainReference
  const chainRef = hex.substring(offset, offset + chainRefLength * 2);
  offset += chainRefLength * 2;
  
  // Convert chain reference to decimal
  const chainId = parseInt(chainRef || '0', 16);
  
  // Read address length (1 byte = 2 hex chars)
  const addressLength = parseInt(hex.substring(offset, offset + 2), 16);
  offset += 2;
  
  // Read address
  const address = '0x' + hex.substring(offset, offset + addressLength * 2);
  
  return {
    version,
    chainType,
    chainId,
    address,
    isEIP155: chainType === '0x0000'
  };
}

/**
 * Query controlled accounts from ENS
 */
async function queryControlledAccounts(id = 0) {
  console.log(`\n🔍 Querying ${ENS_NAME} on Sepolia...\n`);
  
  try {
    // Get the resolver address for the ENS name
    console.log(`📡 Resolving ENS name: ${ENS_NAME}`);
    const resolverAddress = await client.getEnsResolver({ name: ENS_NAME });
    
    if (!resolverAddress) {
      console.error('❌ No resolver found for this ENS name');
      process.exit(1);
    }
    
    console.log(`✅ Resolver found: ${resolverAddress}\n`);
    
    // Query the text record
    const textKey = `${TEXT_RECORD_PREFIX}${id}`;
    console.log(`📋 Querying text record: "${textKey}"`);
    
    const yamlOutput = await client.getEnsText({
      name: ENS_NAME,
      key: textKey,
    });
    
    if (!yamlOutput) {
      console.error(`❌ No data found for ID ${id}`);
      console.log('\n💡 Try a different ID or check if controlled accounts are registered');
      process.exit(1);
    }
    
    console.log(`✅ Data found!\n`);
    
    // Parse YAML
    console.log('📄 Raw YAML Output:');
    console.log('─'.repeat(60));
    console.log(yamlOutput);
    console.log('─'.repeat(60));
    console.log();
    
    // Parse and decode
    const data = yaml.load(yamlOutput);
    
    console.log('🔓 Decoded Data:');
    console.log('─'.repeat(60));
    console.log(`ID: ${data.id}`);
    console.log(`Registered At: ${data.registeredAt} (${new Date(data.registeredAt * 1000).toISOString()})`);
    console.log();
    
    // Decode parent
    const parent = decodeERC7930Address(data.parent);
    console.log('👤 Parent Account:');
    console.log(`   Address: ${parent.address}`);
    console.log(`   Chain: ${parent.chainId} (${parent.isEIP155 ? 'EIP-155' : 'Unknown'})`);
    console.log();
    
    // Decode children
    console.log(`👥 Controlled Accounts (${data.children.length}):`);
    data.children.forEach((child, index) => {
      const decoded = decodeERC7930Address(child);
      console.log(`   ${index + 1}. ${decoded.address}`);
      console.log(`      Chain: ${decoded.chainId}`);
    });
    console.log('─'.repeat(60));
    console.log();
    
    // Verify on Etherscan
    console.log('🔗 Verify on Etherscan:');
    console.log(`   Resolver: https://sepolia.etherscan.io/address/${resolverAddress}`);
    console.log(`   Parent: https://sepolia.etherscan.io/address/${parent.address}`);
    data.children.forEach((child, index) => {
      const decoded = decodeERC7930Address(child);
      console.log(`   Child ${index + 1}: https://sepolia.etherscan.io/address/${decoded.address}`);
    });
    console.log();
    
    console.log('✨ Query completed successfully!\n');
    
  } catch (error) {
    console.error('\n❌ Error querying ENS:');
    console.error(error.message);
    if (error.reason) {
      console.error(`Reason: ${error.reason}`);
    }
    process.exit(1);
  }
}

/**
 * Query resolver-info metadata
 */
async function queryResolverInfo() {
  console.log(`\n🔍 Querying resolver-info for ${ENS_NAME}...\n`);
  
  try {
    const resolverAddress = await client.getEnsResolver({ name: ENS_NAME });
    
    if (!resolverAddress) {
      console.error('❌ No resolver found');
      process.exit(1);
    }
    
    console.log(`✅ Resolver: ${resolverAddress}\n`);
    
    const resolverInfo = await client.getEnsText({
      name: ENS_NAME,
      key: 'resolver-info',
    });
    
    if (!resolverInfo) {
      console.error('❌ No resolver-info found');
      process.exit(1);
    }
    
    console.log('📋 Resolver Info:');
    console.log('─'.repeat(60));
    console.log(resolverInfo);
    console.log('─'.repeat(60));
    console.log();
    
  } catch (error) {
    console.error('\n❌ Error:', error.message);
    process.exit(1);
  }
}

/**
 * Main entry point
 */
async function main() {
  const args = process.argv.slice(2);
  const input = args[0] || '0';
  
  // Check for help flag
  if (input === '-h' || input === '--help') {
    console.log(`
Usage: node scripts/query-ens.js [id|info]

Examples:
  node scripts/query-ens.js        Query controlled accounts ID 0
  node scripts/query-ens.js 1      Query controlled accounts ID 1
  node scripts/query-ens.js info   Query resolver-info metadata

Environment Variables:
  SEPOLIA_RPC_URL    Ethereum Sepolia RPC URL (optional)
                     Default: https://ethereum-sepolia-rpc.publicnode.com
`);
    process.exit(0);
  }
  
  // Query resolver-info
  if (input === 'info') {
    await queryResolverInfo();
    return;
  }
  
  // Query controlled accounts
  const id = parseInt(input);
  if (isNaN(id) || id < 0) {
    console.error('❌ Invalid ID. Must be a non-negative integer.');
    console.log('Use --help for usage information.');
    process.exit(1);
  }
  
  await queryControlledAccounts(id);
}

// Run
main().catch(error => {
  console.error('\n💥 Unexpected error:', error);
  process.exit(1);
});

