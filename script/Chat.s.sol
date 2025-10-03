// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/Chat.sol";

contract DeployChat is Script {
    function run() external returns (Chat) {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Get the deployer address
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("==============================================");
        console.log("Deploying Chat Contract");
        console.log("==============================================");
        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Chain ID:", block.chainid);
        console.log("==============================================");
        
        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the contract
        Chat chatContract = new Chat();
        
        console.log("Chat deployed at:", address(chatContract));
        console.log("Owner:", chatContract.owner());
        console.log("Registration fee:", chatContract.registrationFee());
        console.log("==============================================");
        
        // Stop broadcasting
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("Contract Address:", address(chatContract));
        console.log("Deployer:", deployer);
        console.log("Gas Used: Check transaction receipt");
        console.log("\nVerify contract with:");
        console.log("forge verify-contract", address(chatContract), "src/Chat.sol:Chat --chain-id", block.chainid);
        console.log("==============================================");
        
        return chatContract;
    }
}

// Advanced deployment script with configuration options
contract DeployWithConfig is Script {
    struct DeploymentConfig {
        uint256 registrationFee;
        address owner;
        bool shouldVerify;
    }
    
    function run() external returns (Chat) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Load configuration
        DeploymentConfig memory config = getConfig();
        
        console.log("==============================================");
        console.log("Deploying with Custom Configuration");
        console.log("==============================================");
        console.log("Deployer:", deployer);
        console.log("Custom Registration Fee:", config.registrationFee);
        console.log("Custom Owner:", config.owner);
        console.log("==============================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contract
        Chat chatContract = new Chat();
        
        // Configure contract if needed
        if (config.registrationFee != 0.001 ether) {
            chatContract.setRegistrationFee(config.registrationFee);
            console.log("Registration fee updated to:", config.registrationFee);
        }
        
        // Transfer ownership if different from deployer
        if (config.owner != address(0) && config.owner != deployer) {
            chatContract.transferOwnership(config.owner);
            console.log("Ownership transferred to:", config.owner);
        }
        
        console.log("\nContract deployed at:", address(chatContract));
        
        vm.stopBroadcast();
        
        return chatContract;
    }
    
    function getConfig() internal view returns (DeploymentConfig memory) {
        // Check chain ID for different configurations
        if (block.chainid == 1) {
            // Mainnet
            return DeploymentConfig({
                registrationFee: 0.001 ether,
                owner: address(0), // Use deployer
                shouldVerify: true
            });
        } else if (block.chainid == 11155111) {
            // Sepolia testnet
            return DeploymentConfig({
                registrationFee: 0.001 ether,
                owner: address(0),
                shouldVerify: true
            });
        } else {
            // Local/other networks
            return DeploymentConfig({
                registrationFee: 0.001 ether,
                owner: address(0),
                shouldVerify: false
            });
        }
    }
}

// Script to interact with deployed contract
contract InteractWithContract is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address contractAddress = vm.envAddress("CONTRACT_ADDRESS");
        
        Chat chatContract = Chat(contractAddress);
        
        console.log("==============================================");
        console.log("Interacting with Chat");
        console.log("==============================================");
        console.log("Contract Address:", contractAddress);
        console.log("Message Count:", chatContract.messageCount());
        console.log("Group Count:", chatContract.groupCount());
        console.log("Registration Fee:", chatContract.registrationFee());
        console.log("==============================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Example: Register a user
        // chatContract.registerUser{value: 0.001 ether}("testuser", "QmTestImageHash");
        
        // Example: Send a message
        // chatContract.sendGlobalMessage("Hello from script!");
        
        vm.stopBroadcast();
    }
    
    // Register a test user
    function registerTestUser(
        address contractAddress,
        string memory username,
        string memory imageHash
    ) external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        Chat chatContract = Chat(contractAddress);
        
        vm.startBroadcast(privateKey);
        
        chatContract.registerUser{value: 0.001 ether}(username, imageHash);
        console.log("User registered:", username);
        
        vm.stopBroadcast();
    }
    
    // Send a test message
    function sendTestMessage(
        address contractAddress,
        string memory message
    ) external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        Chat chatContract = Chat(contractAddress);
        
        vm.startBroadcast(privateKey);
        
        chatContract.sendGlobalMessage(message);
        console.log("Message sent:", message);
        
        vm.stopBroadcast();
    }
    
    // Get all usernames
    function getAllUsers(address contractAddress) external view {
        Chat chatContract = Chat(contractAddress);
        
        string[] memory usernames = chatContract.getAllUsernames();
        
        console.log("Total users:", usernames.length);
        for (uint i = 0; i < usernames.length; i++) {
            console.log("User", i, ":", usernames[i]);
        }
    }
}

// Script for testing the full flow
contract TestFullFlow is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Running Full Flow Test");
        console.log("==============================================");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy contract
        Chat chatContract = new Chat();
        console.log("Contract deployed at:", address(chatContract));
        
        // Register first user
        chatContract.registerUser{value: 0.001 ether}("alice", "QmAliceImage");
        console.log("Alice registered");
        
        // Send global message
        chatContract.sendGlobalMessage("Hello CloudFest!");
        console.log("Message sent");
        
        // Create a group
        uint256 groupId = chatContract.createGroup("Developers");
        console.log("Group created with ID:", groupId);
        
        // Send group message
        chatContract.sendGroupMessage(groupId, "Welcome to the dev group!");
        console.log("Group message sent");
        
        // Get user's ENS name
        string memory ensName = chatContract.getENSName(msg.sender);
        console.log("ENS Name:", ensName);
        
        vm.stopBroadcast();
        
        console.log("==============================================");
        console.log("Full flow test completed successfully!");
        console.log("==============================================");
    }
}

// Script for multi-user simulation
contract SimulateMultipleUsers is Script {
    function run() external {
        // This script requires multiple private keys
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("==============================================");
        console.log("Simulating Multiple Users");
        console.log("==============================================");
        
        // Deploy contract
        vm.startBroadcast(deployerPrivateKey);
        Chat chatContract = new Chat();
        console.log("Contract deployed at:", address(chatContract));
        vm.stopBroadcast();
        
        // Simulate Alice
        vm.startBroadcast(deployerPrivateKey);
        chatContract.registerUser{value: 0.001 ether}("alice", "QmAliceImage");
        chatContract.sendGlobalMessage("Hi everyone! I'm Alice");
        console.log("Alice: Registered and sent message");
        vm.stopBroadcast();
        
        // If you have additional test accounts, you can simulate them here
        // For full simulation, you'd need multiple private keys
        
        // Get statistics
        console.log("\nFinal Statistics:");
        console.log("Total messages:", chatContract.messageCount());
        console.log("Total groups:", chatContract.groupCount());
        
        string[] memory usernames = chatContract.getAllUsernames();
        console.log("Total users:", usernames.length);
        
        console.log("==============================================");
    }
}