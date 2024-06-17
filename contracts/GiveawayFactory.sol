// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Giveaway.sol";

// Onboard.Fun
contract GiveawayFactory is OwnableUpgradeable {
    address public admin;
    address[] public giveaways;
    address public tokenImplementation;
    mapping(string => bool) public usedUrls;
    mapping(address => address[]) public ownerGiveaways;

    // Initialize function to replace constructor
    function initialize(address _admin) public initializer {
        __Ownable_init(msg.sender);
        tokenImplementation = address(new Giveaway());
        admin = _admin;
    }

    event GiveawayCreated(address indexed giveawayAddress, string customUrl);

    function isValidSlug(string memory slug) public pure returns (bool) {
        bytes memory b = bytes(slug);
        for(uint i; i<b.length; i++){
            bytes1 char = b[i];
            if(!(char >= 0x30 && char <= 0x39) && // 0-9
               !(char >= 0x41 && char <= 0x5A) && // A-Z
               !(char >= 0x61 && char <= 0x7A) && // a-z
               !(char == 0x2D || char == 0x5F))   // '-' or '_'
               return false;
        }
        return true;
    }

    function createGiveaway(
        address token,
        uint256 amount,
        uint256 numPeople,
        string memory customUrl,
        uint authType,
        string memory banner
    ) public returns (address) {
        require(isValidSlug(customUrl), "Invalid slug");
        require(!usedUrls[customUrl], "Custom URL already used");
        require(IERC20(token).totalSupply() > 0, "Invalid token address");
        address clone = Clones.clone(tokenImplementation);
        Giveaway(clone).initialize(admin, msg.sender, token, amount, numPeople, customUrl, authType, banner);
        uint256 totalAmount = amount * numPeople;
        require(IERC20(token).transferFrom(msg.sender, clone, totalAmount), "Token transfer failed");
        giveaways.push(clone);
        ownerGiveaways[msg.sender].push(clone);
        usedUrls[customUrl] = true;
        emit GiveawayCreated(clone, customUrl);
        return clone;
    }


    function getGiveaways() public view returns (address[] memory) {
        return giveaways;
    }

    function numGiveaways() public view returns (uint256) {
        return giveaways.length;
    }

    function isUrlAvailable(string memory customUrl) public view returns (bool) {
        return !usedUrls[customUrl];
    }

    function getGiveawaysByOwner(address owner) public view returns (address[] memory) {
        return ownerGiveaways[owner];
    }

    function setAdmin(address _admin) public onlyOwner {
        admin = _admin;
    }
}
