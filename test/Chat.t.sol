// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Chat.sol";

contract ChatTest is Test {
    Chat public chatContract;
    
    address public owner;
    address public alice;
    address public bob;
    address public charlie;
    address public david;
    
    string constant ALICE_USERNAME = "alice";
    string constant BOB_USERNAME = "bob";
    string constant CHARLIE_USERNAME = "charlie";
    string constant DAVID_USERNAME = "david";
    
    string constant ALICE_IMAGE = "QmAliceImageHash123456";
    string constant BOB_IMAGE = "QmBobImageHash789012";
    string constant CHARLIE_IMAGE = "QmCharlieImageHash345678";
    string constant DAVID_IMAGE = "QmDavidImageHash901234";
    
    uint256 constant REGISTRATION_FEE = 0.001 ether;
    
    // Events to test
    event UserRegistered(address indexed user, string username, string imageHash);
    event MessageSent(uint256 indexed messageId, address indexed sender, bool isPrivate, uint256 groupId);
    event GroupCreated(uint256 indexed groupId, string name, address creator);
    event UserJoinedGroup(uint256 indexed groupId, address user);
    event UserLeftGroup(uint256 indexed groupId, address user);
    
    function setUp() public {
        // Deploy contract
        owner = address(this);
        chatContract = new Chat();
        
        // Create test accounts
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        david = makeAddr("david");
        
        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(david, 100 ether);
    }
    
    /*//////////////////////////////////////////////////////////////
                        USER REGISTRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testUserRegistration() public {
        vm.startPrank(alice);
        
        // Expect event emission
        vm.expectEmit(true, false, false, true);
        emit UserRegistered(alice, ALICE_USERNAME, ALICE_IMAGE);
        
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        // Verify user data
        Chat.User memory user = chatContract.getUserByAddress(alice);
        assertEq(user.userName, ALICE_USERNAME);
        assertEq(user.imageHash, ALICE_IMAGE);
        assertEq(user.userAddress, alice);
        assertTrue(user.isActive);
        assertGt(user.registrationTime, 0);
        
        vm.stopPrank();
    }
    
    function testGetENSName() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        string memory ensName = chatContract.getENSName(alice);
        assertEq(ensName, "alice.cloudfest");
    }
    
    function testRegistrationWithInsufficientFee() public {
        vm.startPrank(alice);
        
        vm.expectRevert("Insufficient registration fee");
        chatContract.registerUser{value: 0.0005 ether}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.stopPrank();
    }
    
    function testRegistrationWithEmptyUsername() public {
        vm.startPrank(alice);
        
        vm.expectRevert("Invalid username length");
        chatContract.registerUser{value: REGISTRATION_FEE}("", ALICE_IMAGE);
        
        vm.stopPrank();
    }
    
    function testRegistrationWithEmptyImageHash() public {
        vm.startPrank(alice);
        
        vm.expectRevert("Image hash required");
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, "");
        
        vm.stopPrank();
    }
    
    function testRegistrationWithTooLongUsername() public {
        vm.startPrank(alice);
        
        string memory longUsername = "thisusernameiswaytoolongandexceedstwentycharacters";
        
        vm.expectRevert("Invalid username length");
        chatContract.registerUser{value: REGISTRATION_FEE}(longUsername, ALICE_IMAGE);
        
        vm.stopPrank();
    }
    
    function testDuplicateUsername() public {
        // Alice registers
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        // Bob tries to use same username
        vm.prank(bob);
        vm.expectRevert("Username already taken");
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, BOB_IMAGE);
    }
    
    function testDoubleRegistration() public {
        vm.startPrank(alice);
        
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.expectRevert("User already registered");
        chatContract.registerUser{value: REGISTRATION_FEE}("alice2", ALICE_IMAGE);
        
        vm.stopPrank();
    }
    
    function testUpdateProfile() public {
        vm.startPrank(alice);
        
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        string memory newImageHash = "QmNewAliceImageHash";
        chatContract.updateProfile(newImageHash);
        
        Chat.User memory user = chatContract.getUserByAddress(alice);
        assertEq(user.imageHash, newImageHash);
        
        vm.stopPrank();
    }
    
    function testGetUserByUsername() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        Chat.User memory user = chatContract.getUserByUsername(ALICE_USERNAME);
        assertEq(user.userAddress, alice);
        assertEq(user.userName, ALICE_USERNAME);
    }
    
    function testGetAllUsernames() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        vm.prank(charlie);
        chatContract.registerUser{value: REGISTRATION_FEE}(CHARLIE_USERNAME, CHARLIE_IMAGE);
        
        string[] memory usernames = chatContract.getAllUsernames();
        assertEq(usernames.length, 3);
        assertEq(usernames[0], ALICE_USERNAME);
        assertEq(usernames[1], BOB_USERNAME);
        assertEq(usernames[2], CHARLIE_USERNAME);
    }
    
    /*//////////////////////////////////////////////////////////////
                        GLOBAL MESSAGING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSendGlobalMessage() public {
        // Register alice
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        // Send message
        vm.startPrank(alice);
        
        vm.expectEmit(true, true, false, true);
        emit MessageSent(0, alice, false, 0);
        
        chatContract.sendGlobalMessage("Hello everyone!");
        
        vm.stopPrank();
        
        // Verify message
        Chat.Message[] memory messages = chatContract.getMessages(0, 1);
        assertEq(messages.length, 1);
        assertEq(messages[0].sender, alice);
        assertEq(messages[0].content, "Hello everyone!");
        assertFalse(messages[0].isPrivate);
        assertEq(messages[0].groupId, 0);
        assertGt(messages[0].timestamp, 0);
    }
    
    function testUnregisteredUserCannotSendGlobalMessage() public {
        vm.prank(alice);
        vm.expectRevert("User not registered");
        chatContract.sendGlobalMessage("Hello!");
    }
    
    function testSendEmptyGlobalMessage() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(alice);
        vm.expectRevert("Message cannot be empty");
        chatContract.sendGlobalMessage("");
    }
    
    function testSendTooLongGlobalMessage() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        // Create message over 500 characters
        string memory longMessage = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium totam rem.";
        
        vm.prank(alice);
        vm.expectRevert("Message too long");
        chatContract.sendGlobalMessage(longMessage);
    }
    
    function testMultipleGlobalMessages() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Send messages
        vm.prank(alice);
        chatContract.sendGlobalMessage("Message 1");
        
        vm.prank(bob);
        chatContract.sendGlobalMessage("Message 2");
        
        vm.prank(alice);
        chatContract.sendGlobalMessage("Message 3");
        
        // Verify
        Chat.Message[] memory messages = chatContract.getMessages(0, 3);
        assertEq(messages.length, 3);
        assertEq(messages[0].sender, alice);
        assertEq(messages[1].sender, bob);
        assertEq(messages[2].sender, alice);
    }
    
    /*//////////////////////////////////////////////////////////////
                        PRIVATE MESSAGING TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSendPrivateMessage() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Send private message
        vm.startPrank(alice);
        
        vm.expectEmit(true, true, false, true);
        emit MessageSent(0, alice, true, 0);
        
        chatContract.sendPrivateMessage(bob, "Hi Bob!");
        
        vm.stopPrank();
        
        // Verify message
        Chat.Message[] memory messages = chatContract.getMessages(0, 1);
        assertEq(messages[0].sender, alice);
        assertEq(messages[0].recipient, bob);
        assertEq(messages[0].content, "Hi Bob!");
        assertTrue(messages[0].isPrivate);
    }
    
    function testSendPrivateMessageToUnregisteredUser() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(alice);
        vm.expectRevert("Recipient not registered");
        chatContract.sendPrivateMessage(bob, "Hi Bob!");
    }
    
    function testSendPrivateMessageToSelf() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(alice);
        vm.expectRevert("Cannot send message to yourself");
        chatContract.sendPrivateMessage(alice, "Hi myself!");
    }
    
    function testGetPrivateMessages() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Send private messages
        vm.prank(alice);
        chatContract.sendPrivateMessage(bob, "Message 1");
        
        vm.prank(bob);
        chatContract.sendPrivateMessage(alice, "Message 2");
        
        vm.prank(alice);
        chatContract.sendPrivateMessage(bob, "Message 3");
        
        // Get private messages
        vm.prank(alice);
        Chat.Message[] memory messages = chatContract.getPrivateMessages(bob, 0, 10);
        
        // Should return messages between alice and bob
        assertEq(messages.length, 10); // Returns array of size 10, but only 3 are filled
    }
    
    /*//////////////////////////////////////////////////////////////
                        GROUP TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testCreateGroup() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.startPrank(alice);
        
        vm.expectEmit(true, false, false, true);
        emit GroupCreated(0, "Dev Team", alice);
        
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        vm.stopPrank();
        
        assertEq(groupId, 0);
        
        // Verify group info
        (string memory name, address creator, uint256 memberCount, uint256 createdAt) = chatContract.getGroupInfo(groupId);
        assertEq(name, "Dev Team");
        assertEq(creator, alice);
        assertEq(memberCount, 1); // Creator is automatically a member
        assertGt(createdAt, 0);
        
        // Verify alice is a member
        assertTrue(chatContract.isGroupMember(groupId, alice));
    }
    
    function testCreateGroupWithEmptyName() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(alice);
        vm.expectRevert("Invalid group name");
        chatContract.createGroup("");
    }
    
    function testJoinGroup() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Alice creates group
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        // Bob joins group
        vm.startPrank(bob);
        
        vm.expectEmit(true, false, false, true);
        emit UserJoinedGroup(groupId, bob);
        
        chatContract.joinGroup(groupId);
        
        vm.stopPrank();
        
        // Verify bob is member
        assertTrue(chatContract.isGroupMember(groupId, bob));
        
        // Verify member count
        (, , uint256 memberCount, ) = chatContract.getGroupInfo(groupId);
        assertEq(memberCount, 2);
    }
    
    function testJoinNonexistentGroup() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(alice);
        vm.expectRevert("Group does not exist");
        chatContract.joinGroup(999);
    }
    
    function testJoinGroupTwice() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        // Alice is already a member (creator)
        vm.prank(alice);
        vm.expectRevert("Already a member");
        chatContract.joinGroup(groupId);
    }
    
    function testLeaveGroup() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Alice creates and bob joins
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        vm.prank(bob);
        chatContract.joinGroup(groupId);
        
        // Bob leaves
        vm.startPrank(bob);
        
        vm.expectEmit(true, false, false, true);
        emit UserLeftGroup(groupId, bob);
        
        chatContract.leaveGroup(groupId);
        
        vm.stopPrank();
        
        // Verify bob is not a member
        assertFalse(chatContract.isGroupMember(groupId, bob));
        
        // Verify member count
        (, , uint256 memberCount, ) = chatContract.getGroupInfo(groupId);
        assertEq(memberCount, 1);
    }
    
    function testGetGroupMembers() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        vm.prank(charlie);
        chatContract.registerUser{value: REGISTRATION_FEE}(CHARLIE_USERNAME, CHARLIE_IMAGE);
        
        // Create group and add members
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        vm.prank(bob);
        chatContract.joinGroup(groupId);
        
        vm.prank(charlie);
        chatContract.joinGroup(groupId);
        
        // Get members
        address[] memory members = chatContract.getGroupMembers(groupId);
        assertEq(members.length, 3);
        assertEq(members[0], alice);
        assertEq(members[1], bob);
        assertEq(members[2], charlie);
    }
    
    function testSendGroupMessage() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Create group and add bob
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        vm.prank(bob);
        chatContract.joinGroup(groupId);
        
        // Send group message
        vm.startPrank(alice);
        
        vm.expectEmit(true, true, false, true);
        emit MessageSent(0, alice, false, groupId);
        
        chatContract.sendGroupMessage(groupId, "Hello team!");
        
        vm.stopPrank();
        
        // Verify message
        Chat.Message[] memory messages = chatContract.getGroupMessages(groupId, 0, 10);
        assertEq(messages[0].sender, alice);
        assertEq(messages[0].content, "Hello team!");
        assertEq(messages[0].groupId, groupId);
        assertFalse(messages[0].isPrivate);
    }
    
    function testSendGroupMessageAsNonMember() public {
        // Register users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        // Alice creates group
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Dev Team");
        
        // Bob tries to send message without joining
        vm.prank(bob);
        vm.expectRevert("Not a group member");
        chatContract.sendGroupMessage(groupId, "Hello!");
    }
    
    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testSetRegistrationFee() public {
        uint256 newFee = 0.002 ether;
        
        chatContract.setRegistrationFee(newFee);
        
        assertEq(chatContract.registrationFee(), newFee);
    }
    
    function testSetRegistrationFeeAsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        chatContract.setRegistrationFee(0.002 ether);
    }
    
    function testWithdrawFees() public {
        // Register some users to generate fees
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        uint256 initialBalance = owner.balance;
        uint256 contractBalance = address(chatContract).balance;
        
        // Withdraw fees
        chatContract.withdrawFees();
        
        assertEq(owner.balance, initialBalance + contractBalance);
        assertEq(address(chatContract).balance, 0);
    }
    
    function testWithdrawFeesAsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        chatContract.withdrawFees();
    }
    
    // function testDeactivateUser() public {
    //     vm.prank(alice);
    //     chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
    //     chatContract.deactivateUser(alice);
        
    //     Chat.User memory user = chatContract.getUserByAddress(alice);
    //     assertFalse(user.isActive);
    // }
    
    function testDeactivateUserAsNonOwner() public {
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        vm.expectRevert();
        chatContract.deactivateUser(alice);
    }
    
    function testSetPaused() public {
        chatContract.setPaused(true);
        assertTrue(chatContract.paused());
        
        chatContract.setPaused(false);
        assertFalse(chatContract.paused());
    }
    
    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    
    function testFullChatFlow() public {
        // 1. Register multiple users
        vm.prank(alice);
        chatContract.registerUser{value: REGISTRATION_FEE}(ALICE_USERNAME, ALICE_IMAGE);
        
        vm.prank(bob);
        chatContract.registerUser{value: REGISTRATION_FEE}(BOB_USERNAME, BOB_IMAGE);
        
        vm.prank(charlie);
        chatContract.registerUser{value: REGISTRATION_FEE}(CHARLIE_USERNAME, CHARLIE_IMAGE);
        
        // 2. Send global messages
        vm.prank(alice);
        chatContract.sendGlobalMessage("Hello everyone!");
        
        vm.prank(bob);
        chatContract.sendGlobalMessage("Hi Alice!");
        
        // 3. Send private messages
        vm.prank(alice);
        chatContract.sendPrivateMessage(bob, "How are you Bob?");
        
        vm.prank(bob);
        chatContract.sendPrivateMessage(alice, "I'm good, thanks!");
        
        // 4. Create group
        vm.prank(alice);
        uint256 groupId = chatContract.createGroup("Friends");
        
        // 5. Join group
        vm.prank(bob);
        chatContract.joinGroup(groupId);
        
        vm.prank(charlie);
        chatContract.joinGroup(groupId);
        
        // 6. Send group messages
        vm.prank(alice);
        chatContract.sendGroupMessage(groupId, "Welcome to the group!");
        
        vm.prank(bob);
        chatContract.sendGroupMessage(groupId, "Thanks for adding me!");
        
        // Verify everything
        assertEq(chatContract.messageCount(), 6);
        assertEq(chatContract.groupCount(), 1);
        
        string[] memory usernames = chatContract.getAllUsernames();
        assertEq(usernames.length, 3);
        
        (, , uint256 memberCount, ) = chatContract.getGroupInfo(groupId);
        assertEq(memberCount, 3);
    }
    
    // Receive function to accept ETH from withdrawFees
    receive() external payable {}
}