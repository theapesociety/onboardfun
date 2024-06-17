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
    uint public authType; // 0 for Twitter, 1 for Farcaster, 2 for Either
    uint public status; // 0 = Inactive, 1 = Active, 2 = Completed, 3 = Cancelled
    string public banner;
    mapping(address => bool) public isAuthenticated;
    mapping(address => bool) public hasClaimed;
    uint256 public claimedCount;

    constructor() {
        owner = msg.sender; // This sets the deployer as the owner; modify as needed
    }

    event Authenticated(address indexed user, bool status);
    event TokensClaimed(address indexed user, uint256 amount);
    event StatusChange(uint status);
    event Initialized(address admin, address owner, address token, uint256 amount, uint256 numPeople, string customUrl, uint authType, string banner);
    event BannerChange(string banner);

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
        uint _authType,
        string memory _banner
    ) external {
        require(owner == address(0), "Already initialized"); // Ensure it's not re-initialized
        admin = _admin;
        owner = _owner;
        token = _token;
        amount = _amount;
        numPeople = _numPeople;
        customUrl = _customUrl;
        authType = _authType;
        banner = _banner;
        status = 0; // Default to inactive
        emit Initialized(admin, owner, token, amount, numPeople, customUrl, authType, banner);
    }

    // Function to change the status
    function setStatus(uint _status) public {
        require(msg.sender == owner, "Only owner can change status");
        status = _status;
        emit StatusChange(status);
    }

    // Function to update the banner
    function setBanner(string memory _banner) public {
        require(msg.sender == owner, "Only owner can change the banner");
        banner = _banner;
        emit BannerChange(banner);
    }

    function claimTokens() public nonReentrant {
        require(isAuthenticated[msg.sender], "User not authenticated.");
        require(!hasClaimed[msg.sender], "Tokens already claimed.");
        require(status == 1, "Giveaway not open.");
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient token balance.");
        require(IERC20(token).transfer(msg.sender, amount), "Token transfer failed.");
        hasClaimed[msg.sender] = true;
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
        uint, 
        uint,
        uint256,
        string memory
    ) {
        return (
            admin,
            owner,
            token,
            amount,
            numPeople,
            customUrl,
            authType,
            status,
            claimedCount,
            banner
        );
    }
}
