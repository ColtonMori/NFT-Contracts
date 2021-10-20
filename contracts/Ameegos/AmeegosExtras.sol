// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../WithMintPass.sol";

/*
 Simple ERC1155 contract for initial sale. It represents in-game items, so each option corresponds to an game item, like: Skin, Weapon, Armor.
 
 The features:
 - admin can add new items to the marketplace (name, price, max supply)
 - admin can lower max supply of an item
 - admin can change price for each item
 - users can purchase item if minter didn't run out of supply and if saleStarted = true

 - admin can withdraw funds from sale, but 10% goes to the developer address "0x704C043CeB93bD6cBE570C6A2708c3E1C0310587"
 - tokens are burnable
 - admin can flipSaleStarted, switching between sale active or disabled (saleStarted is true/false)

 Items are stored in array of struct GameItem.

 In ERC1155, tokens have id, which represents itemId.
 */


/// @custom:security-contact aleks@buildship.dev
contract AmeegosExtras is ERC1155, WithMintPass, Ownable {
    // Buildship storage
    address payable buildship = payable(0x704C043CeB93bD6cBE570C6A2708c3E1C0310587);
    uint256 constant DEVELOPER_FEE = 1000; // of 10000;

    constructor(IERC721 _mintPass)
        ERC1155("https://metadata.buildship.dev/api/token/ameegos-extra/{id}")
        WithMintPass(_mintPass, 3, MintPassLogic.LimitAddress)
    {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    struct GameItem {
        uint256 price;
        uint256 maxSupply;
        uint256 mintedSupply;
        string name;
    }

    mapping(uint256 => GameItem) public items;
    // keep track of total number of items
    uint256 public totalItems;

    mapping (uint256 => bool) private _saleStarted;

    modifier whenSaleStarted(uint256 itemId) {
        require(_saleStarted[itemId], "Sale not started");
        _;
    }

    // ----- View functions -----

    function saleStarted(uint256 itemId) public view returns(bool) {
        return _saleStarted[itemId];
    }

    // ----- User functions -----

    // Buy item
    function buyItem(uint256 itemId, uint256 amount)
        public
        whenSaleStarted(itemId)
        payable
    {
        require(itemId < totalItems, "No itemId");

        GameItem storage item = items[itemId];

        require(item.mintedSupply + amount <= items[itemId].maxSupply, "Out of stock");
        require(item.price * amount <= msg.value, "Not enough ETH");

        // buy item
        item.mintedSupply += amount;
        _mint(msg.sender, itemId, amount, "");
    }

    function claimItem(uint256 itemId, uint256 amount) public whenSaleStarted(itemId) withMintPass(amount) {

        require(itemId < totalItems, "No itemId");

        GameItem storage item = items[itemId];

        require(item.mintedSupply + amount <= item.maxSupply, "Out of stock");

        item.mintedSupply += amount;
        _mint(msg.sender, itemId, amount, "");

    }

    // ----- Admin functions -----

    function flipSaleStarted(uint256 itemId) external onlyOwner {
        _saleStarted[itemId] = !_saleStarted[itemId];
    }

    function startSaleAll() external onlyOwner {
        for (uint256 itemId = 0; itemId < totalItems; itemId++) {
            _saleStarted[itemId] = true;
        }
    }

    // Add new item to the marketplace
    // @notice Dont forget to add tokenId metadata to backend
    function addItem(string memory name, uint256 price, uint256 maxSupply, bool startSale) public onlyOwner {
        require(maxSupply > 0, "Invalid maxSupply");

        uint256 newItemId = totalItems;

        // create new item
        GameItem memory item = GameItem(price, maxSupply, 0, name);

        // add item to the array
        items[newItemId] = item;
        totalItems++;

        // should start sale right after adding?
        _saleStarted[newItemId] = startSale;

    }

    // Change price for item
    function changePrice(uint256 itemId, uint256 newPrice) public onlyOwner {
        // require(newPrice > 0);

        // change price
        items[itemId].price = newPrice;
    }

    // Withdraw sale money
    function withdraw() public onlyOwner {
        uint256 _balance = address(this).balance;

        uint256 baseAmount = _balance * (10000 - DEVELOPER_FEE) / 10000;
        uint256 feesAmount = _balance * (DEVELOPER_FEE) / 10000;

        require(payable(msg.sender).send(baseAmount));
        require(payable(buildship).send(feesAmount));
    }

}
