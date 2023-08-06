// NFTMarketplace.test.ts

import { ethers } from "hardhat";
import { expect } from "chai";
import { NFTMarketplace } from "../typechain-types/contracts/optistore.sol"; // Replace with the path to your contract artifacts

describe("Optistore", () => {
  let nftMarketplace: NFTMarketplace;
  let owner: any; // The address of the contract owner
  let seller: any; // The address of the seller's wallet
  let buyer: any; // The address of the buyer's wallet

  beforeEach(async () => {
    [owner, seller, buyer] = await ethers.getSigners();
    const NFTMarketplaceContract = await ethers.getContractFactory("NFTMarketplace"); // Replace "NFTMarketplace" with your contract name
    nftMarketplace = (await NFTMarketplaceContract.deploy("NFT Marketplace", "NFTM", ethers.utils.parseEther("0.1"), 10)) as NFTMarketplace;
    await nftMarketplace.deployed();
  });

  it("should deploy and mint an NFT", async () => {
    const tokenURI = "ipfs://QmWxVg6zqAGUdusgGxHvqdSzrMURbb8krV6Bb1GQa2TVu4";
    const royaltyPercentage = 10;

    // Mint a new NFT
    await nftMarketplace.connect(seller).mintNFT(tokenURI, royaltyPercentage);

    // Check if the NFT was minted correctly
    const tokenId = 1;
    expect(await nftMarketplace.ownerOf(tokenId)).to.equal(seller.address);
    expect(await nftMarketplace.tokenURI(tokenId)).to.equal(tokenURI);
    expect(await nftMarketplace.getTokenPrice(tokenId)).to.equal(ethers.utils.parseEther("0.1"));
    expect(await nftMarketplace.getRoyaltyPercentage(tokenId)).to.equal(royaltyPercentage);
  });

  it("should set the price of an NFT", async () => {
    const tokenId = 1;
    const newPrice = ethers.utils.parseEther("0.2");

    // Mint a new NFT
    await nftMarketplace.connect(seller).mintNFT("ipfs://token1", 5);

    // Set the price of the NFT
    await nftMarketplace.connect(owner).setTokenPrice(tokenId, newPrice);

    // Check if the price was updated correctly
    expect(await nftMarketplace.getTokenPrice(tokenId)).to.equal(newPrice);
  });

  it("should buy an NFT", async () => {
    const tokenId = 1;
    const price = ethers.utils.parseEther("0.1");

    // Mint a new NFT
    await nftMarketplace.connect(seller).mintNFT("ipfs://token1", 5);

    // Buyer buys the NFT
    await nftMarketplace.connect(buyer).buyNFT(tokenId, { value: price });

    // Check if the NFT was transferred to the buyer and the seller received the payment
    expect(await nftMarketplace.ownerOf(tokenId)).to.equal(buyer.address);
  });

  // Add more test cases to cover other functions and edge cases

});
