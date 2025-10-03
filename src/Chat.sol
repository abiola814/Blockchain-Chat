// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract Chat is Ownable, ReentrancyGuard {
   struct User{
    string userName;
    string imageHash;
    uint256 registrationTime;
    bool isActive;
    address userAddress;
   }

   struct Message {
    address sender;
    address recipient;
    bool isPrivate;
    string content;
    uint256 timestamp;
    uint256 groupId;
   }

   struct Group {
    address creator;
    mapping(address => bool) members;
    address[] memberList;
    uint256 createdAt;
    string name;
    bool isActive;

   }




    // State variables
    mapping(string => address) public usernameToAddress;
    mapping(address => User) public users;
    mapping(uint256 => Message) public messages;
    mapping(uint256 => Group) public groups;
    
    string[] public usernames;
    uint256 public messageCount;
    uint256 public groupCount;
    uint256 public registrationFee = 0.001 ether;

    // Events
    event UserRegistered(address indexed user, string username, string imageHash);
    event MessageSent(uint256 indexed messageId, address indexed sender, bool isPrivate, uint256 groupId);
    event GroupCreated(uint256 indexed groupId, string name, address creator);
    event UserJoinedGroup(uint256 indexed groupId, address user);
    event UserLeftGroup(uint256 indexed groupId, address user);

    constructor() Ownable(msg.sender) {}

    modifier onlyRegisteredUser() {
        require(users[msg.sender].isActive, "User not registered");
        _;
    }
 
    modifier usernameAvailable(string memory _username) {
        require(usernameToAddress[_username] == address(0), "Username already taken");
        require(bytes(_username).length > 0 && bytes(_username).length <= 20, "Invalid username length");
        _;
    }

    // User Registration
    function registerUser(string memory _username, string memory _imageHash) 
        external 
        payable 
        usernameAvailable(_username) 
        nonReentrant 
    {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(!users[msg.sender].isActive, "User already registered");
        require(bytes(_imageHash).length > 0, "Image hash required");

        users[msg.sender] = User({
            userName: _username,
            imageHash: _imageHash,
            userAddress: msg.sender,
            registrationTime: block.timestamp,
            isActive: true
        });

        usernameToAddress[_username] = msg.sender;
        usernames.push(_username);

        emit UserRegistered(msg.sender, _username, _imageHash);
    }

    // Update user profile
    function updateProfile(string memory _imageHash) external onlyRegisteredUser {
        require(bytes(_imageHash).length > 0, "Image hash required");
        users[msg.sender].imageHash = _imageHash;
    }

    // Send message to global chat
    function sendGlobalMessage(string memory _content) external onlyRegisteredUser {
        require(bytes(_content).length > 0, "Message cannot be empty");
        require(bytes(_content).length <= 500, "Message too long");

        messages[messageCount] = Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp,
            isPrivate: false,
            recipient: address(0),
            groupId: 0
        });

        emit MessageSent(messageCount, msg.sender, false, 0);
        messageCount++;
    }

    // Send private message
    function sendPrivateMessage(address _recipient, string memory _content) 
        external 
        onlyRegisteredUser 
    {
        require(users[_recipient].isActive, "Recipient not registered");
        require(bytes(_content).length > 0, "Message cannot be empty");
        require(bytes(_content).length <= 500, "Message too long");
        require(_recipient != msg.sender, "Cannot send message to yourself");

        messages[messageCount] = Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp,
            isPrivate: true,
            recipient: _recipient,
            groupId: 0
        });

        emit MessageSent(messageCount, msg.sender, true, 0);
        messageCount++;
    }

    // Create a group
    function createGroup(string memory _groupName) external onlyRegisteredUser returns (uint256) {
        require(bytes(_groupName).length > 0 && bytes(_groupName).length <= 50, "Invalid group name");

        uint256 groupId = groupCount;
        Group storage newGroup = groups[groupId];
        newGroup.name = _groupName;
        newGroup.creator = msg.sender;
        newGroup.createdAt = block.timestamp;
        newGroup.isActive = true;
        newGroup.members[msg.sender] = true;
        newGroup.memberList.push(msg.sender);

        groupCount++;
        emit GroupCreated(groupId, _groupName, msg.sender);
        
        return groupId;
    }

    // Join a group
    function joinGroup(uint256 _groupId) external onlyRegisteredUser {
        require(_groupId < groupCount, "Group does not exist");
        require(groups[_groupId].isActive, "Group is not active");
        require(!groups[_groupId].members[msg.sender], "Already a member");

        groups[_groupId].members[msg.sender] = true;
        groups[_groupId].memberList.push(msg.sender);

        emit UserJoinedGroup(_groupId, msg.sender);
    }

    // Leave a group
    function leaveGroup(uint256 _groupId) external onlyRegisteredUser {
        require(_groupId < groupCount, "Group does not exist");
        require(groups[_groupId].members[msg.sender], "Not a member");

        groups[_groupId].members[msg.sender] = false;
        
        // Remove from member list
        address[] storage memberList = groups[_groupId].memberList;
        for (uint i = 0; i < memberList.length; i++) {
            if (memberList[i] == msg.sender) {
                memberList[i] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }

        emit UserLeftGroup(_groupId, msg.sender);
    }

    // Send message to group
    function sendGroupMessage(uint256 _groupId, string memory _content) 
        external 
        onlyRegisteredUser 
    {
        require(_groupId < groupCount, "Group does not exist");
        require(groups[_groupId].isActive, "Group is not active");
        require(groups[_groupId].members[msg.sender], "Not a group member");
        require(bytes(_content).length > 0, "Message cannot be empty");
        require(bytes(_content).length <= 500, "Message too long");

        messages[messageCount] = Message({
            sender: msg.sender,
            content: _content,
            timestamp: block.timestamp,
            isPrivate: false,
            recipient: address(0),
            groupId: _groupId
        });

        emit MessageSent(messageCount, msg.sender, false, _groupId);
        messageCount++;
    }

    // View functions
    function getUserByUsername(string memory _username) external view returns (User memory) {
        address userAddr = usernameToAddress[_username];
        require(userAddr != address(0), "Username not found");
        return users[userAddr];
    }

    function getUserByAddress(address _user) external view returns (User memory) {
        require(users[_user].isActive, "User not found");
        return users[_user];
    }

    function getENSName(address _user) external view returns (string memory) {
        require(users[_user].isActive, "User not registered");
        return string(abi.encodePacked(users[_user].userName, ".cloudfest"));
    }

    function isGroupMember(uint256 _groupId, address _user) external view returns (bool) {
        require(_groupId < groupCount, "Group does not exist");
        return groups[_groupId].members[_user];
    }

    function getGroupMembers(uint256 _groupId) external view returns (address[] memory) {
        require(_groupId < groupCount, "Group does not exist");
        return groups[_groupId].memberList;
    }

    function getGroupInfo(uint256 _groupId) external view returns (string memory name, address creator, uint256 memberCount, uint256 createdAt) {
        require(_groupId < groupCount, "Group does not exist");
        Group storage group = groups[_groupId];
        return (group.name, group.creator, group.memberList.length, group.createdAt);
    }

    function getAllUsernames() external view returns (string[] memory) {
        return usernames;
    }

    // Get messages with pagination
    function getMessages(uint256 _start, uint256 _count) 
        external 
        view 
        returns (Message[] memory) 
    {
        require(_start < messageCount, "Start index out of bounds");
        
        uint256 end = _start + _count;
        if (end > messageCount) {
            end = messageCount;
        }
        
        Message[] memory result = new Message[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            result[i - _start] = messages[i];
        }
        
        return result;
    }

    // Get private messages between two users
    function getPrivateMessages(address _otherUser, uint256 _start, uint256 _count) 
        external 
        view 
        onlyRegisteredUser
        returns (Message[] memory) 
    {
        require(users[_otherUser].isActive, "Other user not registered");
        
        // Count relevant messages first
        uint256 relevantCount = 0;
        for (uint256 i = 0; i < messageCount; i++) {
            Message storage message = messages[i];
            if (message.isPrivate && 
                ((msg.sender == message.sender && message.recipient == _otherUser) ||
                 (message.sender == _otherUser && message.recipient == msg.sender))) {
                relevantCount++;
            }
        }
        
        // Create result array
        Message[] memory result = new Message[](_count);
        uint256 resultIndex = 0;
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < messageCount && resultIndex < _count; i++) {
            Message storage message = messages[i];
            if (message.isPrivate && 
                ((msg.sender == message.sender && message.recipient == _otherUser) ||
                 (message.sender == _otherUser && message.recipient == msg.sender))) {
                if (currentIndex >= _start) {
                    result[resultIndex] = message;
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return result;
    }

    // Get group messages
    function getGroupMessages(uint256 _groupId, uint256 _start, uint256 _count) 
        external 
        view 
        returns (Message[] memory) 
    {
        require(_groupId < groupCount, "Group does not exist");
        
        Message[] memory result = new Message[](_count);
        uint256 resultIndex = 0;
        uint256 currentIndex = 0;
        
        for (uint256 i = 0; i < messageCount && resultIndex < _count; i++) {
            if (!messages[i].isPrivate && messages[i].groupId == _groupId) {
                if (currentIndex >= _start) {
                    result[resultIndex] = messages[i];
                    resultIndex++;
                }
                currentIndex++;
            }
        }
        
        return result;
    }

    // Admin functions
    function setRegistrationFee(uint256 _newFee) external onlyOwner {
        registrationFee = _newFee;
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds to withdraw");
        payable(owner()).transfer(balance);
    }

    function deactivateUser(address _user) external onlyOwner {
        users[_user].isActive = false;
    }

    function deactivateGroup(uint256 _groupId) external onlyOwner {
        require(_groupId < groupCount, "Group does not exist");
        groups[_groupId].isActive = false;
    }

    // Emergency pause (simplified version)
    bool public paused = false;
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }
    
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
}