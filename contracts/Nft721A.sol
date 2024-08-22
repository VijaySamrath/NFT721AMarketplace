// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract Nft721A is ERC721A, ERC2981, Ownable, Pausable {
    uint256 MAX_MINTS = 69;
    uint256 MAX_SUPPLY = 10021;
    uint256 public mintRate = 0.0 ether;

    string public baseURI = "ipfs://QmWcRVmhHAhpPqMvvS4FSC1KpoWCzbzgYm6qhEutcmejdi/";

    struct TokenMetadata {
        string name;
        string symbol;
        string description;
        string uri;
    }

    struct Auction {
        address highestBidder;
        uint256 highestBid;
        uint256 endTime;
        address seller;
        bool ended;
    }

    mapping(uint256 => TokenMetadata) private _tokenMetadata;
    mapping(uint256 => Auction) public auctions;

    constructor(address initialOwner) ERC721A("MyToken", "MTK") Ownable(initialOwner) {
    }

    // Minting function
    function mint(
        uint256 quantity,
        string memory userBaseURI,
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenDescription,
        uint96 royaltyFeeNumerator
    ) external payable whenNotPaused {
        require(quantity + _numberMinted(msg.sender) <= MAX_MINTS, "Exceeded the limit");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Not enough tokens left");
        require(msg.value >= (mintRate * quantity), "Not enough ether sent");

        uint256 startTokenId = _nextTokenId();
        _safeMint(msg.sender, quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = startTokenId + i;
            string memory finalURI = bytes(userBaseURI).length > 0 ? userBaseURI : string(abi.encodePacked(baseURI, _toString(tokenId)));
            _setTokenMetadata(tokenId, tokenName, tokenSymbol, tokenDescription, finalURI);
            _setTokenRoyalty(tokenId, msg.sender, royaltyFeeNumerator);
        }
    }

    // Set token metadata
    function _setTokenMetadata(
        uint256 tokenId,
        string memory name,
        string memory symbol,
        string memory description,
        string memory uri
    ) internal {
        require(_exists(tokenId), "Metadata set of nonexistent token");
        _tokenMetadata[tokenId] = TokenMetadata(name, symbol, description, uri);
    }

    // Get token URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        return _tokenMetadata[tokenId].uri;
    }

    // Get token details
    function tokenDetails(uint256 tokenId) public view returns (string memory name, string memory symbol, string memory description) {
        require(_exists(tokenId), "Details query for nonexistent token");
        TokenMetadata memory metadata = _tokenMetadata[tokenId];
        return (metadata.name, metadata.symbol, metadata.description);
    }

    // Set royalty info
    function setRoyaltyInfo(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    // Batch transfer tokens
    function batchTransferFrom(address from, address to, uint256[] memory tokenIds) external whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    // Create auction
    function createAuction(uint256 tokenId, uint256 startingBid, uint256 duration) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        require(auctions[tokenId].endTime == 0, "Auction already exists");

        auctions[tokenId] = Auction({
            highestBidder: address(0),
            highestBid: startingBid,
            endTime: block.timestamp + duration,
            seller: msg.sender,
            ended: false
        });
        approve(address(this), tokenId); // Approve the contract to transfer the token
    }

    // Place a bid on an auction
    function placeBid(uint256 tokenId) external payable whenNotPaused {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.value > auction.highestBid, "Bid too low");

        // Refund the previous highest bidder
        if (auction.highestBidder != address(0)) {
            payable(auction.highestBidder).transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
    }

    // End auction
    function endAuction(uint256 tokenId) external whenNotPaused {
        Auction storage auction = auctions[tokenId];
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(!auction.ended, "Auction already ended");

        auction.ended = true;
        if (auction.highestBidder != address(0)) {
            payable(auction.seller).transfer(auction.highestBid);
            transferFrom(auction.seller, auction.highestBidder, tokenId);
        } else {
            // No bids were placed, return the token to the seller
            approve(auction.seller, tokenId);
        }
        delete auctions[tokenId];
    }

    // Cancel auction
    function cancelAuction(uint256 tokenId) external whenNotPaused {
        Auction storage auction = auctions[tokenId];
        require(auction.seller == msg.sender, "Not the auction creator");
        require(!auction.ended, "Auction already ended");

        auction.ended = true;
        delete auctions[tokenId];
    }

    // Burn token
    function burn(uint256 tokenId) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        _burn(tokenId);
        delete _tokenMetadata[tokenId];
    }

    // Update token metadata
    function updateTokenMetadata(uint256 tokenId, string memory newURI) external whenNotPaused {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        _tokenMetadata[tokenId].uri = newURI;
    }

    // Pause contract
    function pause() external onlyOwner {
        _pause();
    }

    // Unpause contract
    function unpause() external onlyOwner {
        _unpause();
    }

    // Withdraw funds
    function withdraw() external payable onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Set mint rate
    function setMintRate(uint256 _mintRate) public onlyOwner {
        mintRate = _mintRate;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, ERC2981) returns (bool) {
    return super.supportsInterface(interfaceId);
    }
}


// mint = 1773974, 1542586
//        1771396
