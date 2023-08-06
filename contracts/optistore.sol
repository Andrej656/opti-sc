// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    // Token ID counter
    Counters.Counter private _tokenIdCounter;

    // NFT price in wei
    uint256 private _price;

    // Maximum number of NFTs that can be minted
    uint256 private _maxSupply;

    // Mapping to check if token has been sold
    mapping(uint256 => bool) private _isTokenSold;

    // Mapping to store the current price for each token
    mapping(uint256 => uint256) private _tokenPrices;

    // Mapping to store royalty percentages for each token owner
    mapping(uint256 => uint256) private _tokenRoyalties;

    // Mapping to store the auction details for each token
    mapping(uint256 => Auction) private _tokenAuctions;

    // Struct to hold auction details
    struct Auction {
        address highestBidder;
        uint256 highestBid;
        uint256 auctionEndTime;
    }

    // Events
    event NFTMinted(address indexed owner, uint256 indexed tokenId, string tokenURI, uint256 price);
    event NFTPriceChanged(uint256 indexed tokenId, uint256 price);
    event NFTSold(address indexed buyer, address indexed seller, uint256 indexed tokenId, uint256 price);
    event AuctionStarted(uint256 indexed tokenId, uint256 startPrice, uint256 auctionEndTime);
    event BidPlaced(address indexed bidder, uint256 indexed tokenId, uint256 bidAmount);
    event AuctionEnded(uint256 indexed tokenId, address indexed winner, uint256 indexed finalPrice);
    event RoyaltyPaid(address indexed creator, address indexed owner, uint256 indexed tokenId, uint256 amount);
    event Airdrop(address indexed receiver, uint256 indexed tokenId, string tokenURI);

    constructor(string memory name, string memory symbol, uint256 price, uint256 maxSupply) ERC721(name, symbol) {
        _price = price;
        _maxSupply = maxSupply;
    }

    // Mint a new NFT
    function mintNFT(string memory tokenURI, uint256 royaltyPercentage) public payable {
    require(_tokenIdCounter.current() < _maxSupply, "Maximum supply reached");
    require(msg.value == _price, "Incorrect payment amount");
    require(royaltyPercentage <= 100, "Royalty cannot be greater than 100%");

    uint256 tokenId = _tokenIdCounter.current() + 1;
    _mint(msg.sender, tokenId);
    _setTokenURI(tokenId, tokenURI);
    _tokenPrices[tokenId] = _price;
    _isTokenSold[tokenId] = false;
    _tokenRoyalties[tokenId] = royaltyPercentage;

    emit NFTMinted(msg.sender, tokenId, tokenURI, _price);
    }

    // Set the price of an NFT
    function setTokenPrice(uint256 tokenId, uint256 price) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(!_isTokenSold[tokenId], "Token has already been sold");

        _tokenPrices[tokenId] = price;

        emit NFTPriceChanged(tokenId, price);
    }

    // Buy an NFT
    function buyNFT(uint256 tokenId) public payable {
        require(_exists(tokenId), "Token does not exist");
        require(!_isTokenSold[tokenId], "Token has already been sold");
        require(msg.value == _tokenPrices[tokenId], "Incorrect payment amount");

        address seller = ownerOf(tokenId);

        // Calculate royalties and transfer to creator
        uint256 royaltyPercentage = _tokenRoyalties[tokenId];
        uint256 royaltyAmount = msg.value.mul(royaltyPercentage).div(100);
        (bool success, ) = seller.call{value: royaltyAmount}("");
        require(success, "Royalty payment failed");
        emit RoyaltyPaid(seller, owner(), tokenId, royaltyAmount);

        _transfer(seller, msg.sender, tokenId);
        _isTokenSold[tokenId] = true;

        // Transfer payment to seller
        (success, ) = seller.call{value: msg.value.sub(royaltyAmount)}("");
        require(success, "Payment failed");

        emit NFTSold(msg.sender, seller, tokenId, msg.value);
    }

    // Get the price of an NFT
    function getTokenPrice(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenPrices[tokenId];
    }

    // Get the royalty percentage for an NFT
    function getRoyaltyPercentage(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return _tokenRoyalties[tokenId];
    }

    // Start an auction for an NFT
    function startAuction(uint256 tokenId, uint256 startPrice, uint256 auctionDuration) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(!_isTokenSold[tokenId], "Token has already been sold");
        require(auctionDuration > 0, "Auction duration must be greater than zero");

        // Initialize auction details
        _tokenAuctions[tokenId] = Auction({
            highestBidder: address(0),
            highestBid: 0,
            auctionEndTime: block.timestamp.add(auctionDuration)
        });

        emit AuctionStarted(tokenId, startPrice, _tokenAuctions[tokenId].auctionEndTime);
    }

    // Place a bid for an ongoing auction
    function placeBid(uint256 tokenId) public payable {
        require(_exists(tokenId), "Token does not exist");
        require(!_isTokenSold[tokenId], "Token has already been sold");
        require(_tokenAuctions[tokenId].auctionEndTime > block.timestamp, "Auction has ended");
        require(msg.value > _tokenAuctions[tokenId].highestBid, "Bid must be higher than current highest bid");

        // Refund the previous highest bidder
        if (_tokenAuctions[tokenId].highestBidder != address(0)) {
            (bool success, ) = _tokenAuctions[tokenId].highestBidder.call{value: _tokenAuctions[tokenId].highestBid}("");
            require(success, "Refund failed");
        }

        // Update auction details with new highest bid
        _tokenAuctions[tokenId].highestBidder = msg.sender;
        _tokenAuctions[tokenId].highestBid = msg.value;

        emit BidPlaced(msg.sender, tokenId, msg.value);
    }

    // End the auction and transfer NFT to the highest bidder
    function endAuction(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "Token does not exist");
        require(_tokenAuctions[tokenId].auctionEndTime <= block.timestamp, "Auction has not ended yet");

        address winner = _tokenAuctions[tokenId].highestBidder;
        uint256 finalPrice = _tokenAuctions[tokenId].highestBid;

        // Transfer NFT to the winner
        _transfer(owner(), winner, tokenId);
        _isTokenSold[tokenId] = true;

        // Transfer payment to seller
        (bool success, ) = owner().call{value: finalPrice}("");
        require(success, "Payment failed");

        emit AuctionEnded(tokenId, winner, finalPrice);
    }

    // Withdraw contract balance
    function withdrawBalance() public onlyOwner {
        uint256 balance = address(this).balance;
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Withdrawal failed");
    }

    // Gas optimization: Override the token URI functions to reduce gas costs
    function tokenURI(uint256 tokenId) public view override(ERC721URIStorage) returns (string memory) {
    return ERC721URIStorage.tokenURI(tokenId);


    }

    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
    }

        }

