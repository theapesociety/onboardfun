// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Giveaway.sol";

// Onboard.Fun
contract GiveawayFactory is Ownable {
    address public admin;
    address[] public giveaways;
    address public tokenImplementation;
    address public feeAddress;
    mapping(string => bool) public usedUrls;
    mapping(address => address[]) public ownerGiveaways;

    constructor(address _admin) Ownable(_admin) {
        tokenImplementation = address(new Giveaway());
        admin = _admin;
        feeAddress = _admin;
    }

    event GiveawayCreated(address indexed giveawayAddress, string customUrl);

    function isValidSlug(string memory slug) public pure returns (bool) {
        bytes memory b = bytes(slug);
        for (uint i; i < b.length; i++) {
            bytes1 char = b[i];
            if (
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char >= 0x41 && char <= 0x5A) && // A-Z
                !(char >= 0x61 && char <= 0x7A) && // a-z
                !(char == 0x2D || char == 0x5F)
            )
                return false;
        }
        return true;
    }

    function createGiveaway(
        address token,
        uint256 amount,
        uint256 numPeople,
        string memory customUrl,
        string memory description,
        string memory authType,
        string memory banner,
        string memory socialConfig
    ) public returns (address) {
        require(isValidSlug(customUrl), "Invalid slug");
        require(!usedUrls[customUrl], "Custom URL already used");
        require(IERC20(token).totalSupply() > 0, "Invalid token address");

        address clone = Clones.clone(tokenImplementation);
        Giveaway(clone).initialize(admin, msg.sender, token, amount, numPeople, customUrl, description, authType, banner, socialConfig);

        uint256 totalAmount = amount * numPeople;
        require(IERC20(token).transferFrom(msg.sender, clone, totalAmount), "Token transfer failed");

        require(IERC20(token).transferFrom(msg.sender, feeAddress, totalAmount * 1 / 100), "Fee transfer failed");

        giveaways.push(clone);
        ownerGiveaways[msg.sender].push(clone);
        usedUrls[customUrl] = true;
        emit GiveawayCreated(clone, customUrl);
        return clone;
    }

    function getGiveawayCount() public view returns (uint256) {
        return giveaways.length;
    }

    function getGiveawayByIndex(uint256 index) public view returns (address) {
        require(index < giveaways.length, "Index out of bounds");
        return giveaways[index];
    }

    function getGiveaways() public view returns (address[] memory) {
        return giveaways;
    }

    function numGiveaways() public view returns (uint256) {
        return giveaways.length;
    }

    function changeFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
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
