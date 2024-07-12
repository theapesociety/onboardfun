// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Giveaway is ReentrancyGuard {
    address public admin;
    address public owner;
    address public token;
    uint256 public amount;
    uint256 public numPeople;
    string public customUrl;
    string public description;
    string public socialConfig;
    string public authType;
    uint public status; // 0 = Inactive, 1 = Active, 2 = Completed, 3 = Cancelled
    string public banner;
    mapping(address => bool) public isAuthenticated;
    mapping(address => bool) public hasClaimed;
    mapping(string => bool) public socialClaimed;
    uint256 public claimedCount;

    constructor() {
        owner = msg.sender; // This sets the deployer as the owner; modify as needed
    }

    event Authenticated(address indexed user, bool status);
    event TokensClaimed(address indexed user, uint256 amount);
    event StatusChange(uint status);
    event Initialized(address admin, address owner, address token, uint256 amount, uint256 numPeople, string customUrl, string description, string authType, string banner, string socialConfig);
    event BannerChange(string banner);
    event GiveawayCancelled();


    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function initialize(
        address _admin,
        address _owner,
        address _token,
        uint256 _amount,
        uint256 _numPeople,
        string memory _customUrl,
        string memory _description,
        string memory _authType,
        string memory _banner,
        string memory _socialConfig
    ) external {
        require(owner == address(0), "Already initialized"); // Ensure it's not re-initialized
        admin = _admin;
        owner = _owner;
        token = _token;
        amount = _amount;
        numPeople = _numPeople;
        customUrl = _customUrl;
        description = _description;
        authType = _authType;
        banner = _banner;
        socialConfig = _socialConfig;
        status = 1; // Default to inactive
        emit Initialized(admin, owner, token, amount, numPeople, customUrl, description, authType, banner, socialConfig);
    }

    // Function to change the status
    function setStatus(uint _status) public {
        require(msg.sender == owner, "Only owner can change status");
        require(status != 3, "Cannot change status of a cancelled giveaway");
        status = _status;
        emit StatusChange(status);
    }

    // Function to update the banner
    function setBanner(string memory _banner) public {
        require(msg.sender == owner, "Only owner can change the banner");
        banner = _banner;
        emit BannerChange(banner);
    }

    function claimTokens(string memory social) public nonReentrant {
        require(isAuthenticated[msg.sender], "User not authenticated.");
        require(!hasClaimed[msg.sender], "Tokens already claimed.");
        require(!socialClaimed[social], "Social already connected.");
        require(status == 1, "Giveaway not open.");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance.");
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed.");
        hasClaimed[msg.sender] = true;
        socialClaimed[social] = true;
        emit TokensClaimed(msg.sender, amount);
        claimedCount += 1;
        if (claimedCount == numPeople) {
            status = 2;
            emit StatusChange(status);
        }
    }

    function setAuthenticated(address user, bool _status) public onlyAdmin {
        isAuthenticated[user] = _status;
        emit Authenticated(user, _status);
    }

    function userIsAuthenticated(address user) public view returns (bool) {
        return isAuthenticated[user];
    }

    function setAuthenticatedBatch(address[] memory users) public onlyAdmin {
        for (uint i = 0; i < users.length; i++) {
            isAuthenticated[users[i]] = true;
        }
    }

    function cancelGiveaway() public {
        require(msg.sender == owner, "Only owner can cancel the giveaway");
        require(status != 3, "Giveaway already cancelled");
        status = 3;
        uint256 remainingTokens = IERC20(token).balanceOf(address(this));
        require(IERC20(token).transfer(owner, remainingTokens), "Token transfer failed.");
        emit GiveawayCancelled();
    }

    function totalAmount() public view returns (uint256) {
        return numPeople * amount;
    }

    function getClaimableTokens(address user) public view returns (uint256) {
        if (isAuthenticated[user] && !hasClaimed[user]) {
            return amount;
        }
        return 0;
    }

    function getRemainingTokens() public view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getGiveawayDetails() public view returns (
        address, 
        address, 
        address, 
        uint256, 
        uint256, 
        string memory, 
        string memory, 
        string memory, 
        uint,
        uint256,
        string memory,
        string memory
    ) {
        return (
            admin,
            owner,
            token,
            amount,
            numPeople,
            customUrl,
            description,
            authType,
            status,
            claimedCount,
            banner,
            socialConfig
        );
    }
}
