// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ConcertTicketNFT.sol";

/**
 * @title TicketMarketplace
 * @dev Marketplace contract for trading concert ticket NFTs
 */
contract TicketMarketplace is ReentrancyGuard, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;

    // Marketplace fee percentage (in basis points, e.g., 250 = 2.5%)
    uint256 public marketplaceFee = 250;
    
    // Maximum marketplace fee (5%)
    uint256 public constant MAX_MARKETPLACE_FEE = 500;
    
    // Address to receive marketplace fees
    address public feeRecipient;

    // Struct for marketplace items
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        bool sold;
        bool isAuction;
        uint256 auctionEndTime;
        uint256 highestBid;
        address highestBidder;
        uint256 createdAt;
    }

    // Mapping from item ID to market item
    mapping(uint256 => MarketItem) public idToMarketItem;
    
    // Mapping from token ID to item ID
    mapping(address => mapping(uint256 => uint256)) public tokenToItem;
    
    // Mapping for user bids in auctions
    mapping(uint256 => mapping(address => uint256)) public userBids;
    
    // Mapping for auction bidders
    mapping(uint256 => address[]) public auctionBidders;

    // Events
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        uint256 price,
        bool isAuction,
        uint256 auctionEndTime
    );

    event MarketItemSold(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address buyer,
        uint256 price
    );

    event BidPlaced(
        uint256 indexed itemId,
        address indexed bidder,
        uint256 amount
    );

    event AuctionEnded(
        uint256 indexed itemId,
        address indexed winner,
        uint256 winningBid
    );

    event PriceUpdated(
        uint256 indexed itemId,
        uint256 newPrice
    );

    modifier onlyItemOwner(uint256 itemId) {
        require(idToMarketItem[itemId].seller == msg.sender, "Not the item owner");
        _;
    }

    modifier itemExists(uint256 itemId) {
        require(idToMarketItem[itemId].itemId != 0, "Item does not exist");
        _;
    }

    modifier itemNotSold(uint256 itemId) {
        require(!idToMarketItem[itemId].sold, "Item already sold");
        _;
    }

    modifier auctionActive(uint256 itemId) {
        require(idToMarketItem[itemId].isAuction, "Not an auction");
        require(block.timestamp < idToMarketItem[itemId].auctionEndTime, "Auction ended");
        _;
    }

    constructor(address _feeRecipient) {
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Create a market item for sale
     * @param nftContract Address of the NFT contract
     * @param tokenId Token ID to sell
     * @param price Sale price in wei
     * @param isAuction Whether this is an auction
     * @param auctionDuration Duration of auction in seconds (if auction)
     */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        bool isAuction,
        uint256 auctionDuration
    ) external nonReentrant {
        require(price > 0, "Price must be greater than 0");
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not the token owner");
        require(IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) || 
                IERC721(nftContract).getApproved(tokenId) == address(this), "Contract not approved");

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        uint256 auctionEndTime = 0;
        if (isAuction) {
            require(auctionDuration > 0, "Auction duration must be greater than 0");
            auctionEndTime = block.timestamp + auctionDuration;
        }

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(this),
            price,
            false,
            isAuction,
            auctionEndTime,
            0,
            address(0),
            block.timestamp
        );

        tokenToItem[nftContract][tokenId] = itemId;

        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        emit MarketItemCreated(itemId, nftContract, tokenId, msg.sender, price, isAuction, auctionEndTime);
    }

    /**
     * @dev Buy a market item
     * @param itemId ID of the market item
     */
    function buyMarketItem(uint256 itemId) 
        external 
        payable 
        nonReentrant 
        itemExists(itemId) 
        itemNotSold(itemId) 
    {
        MarketItem storage item = idToMarketItem[itemId];
        require(!item.isAuction, "Item is an auction, use bid function");
        require(msg.value >= item.price, "Insufficient payment");

        item.sold = true;
        item.owner = msg.sender;
        _itemsSold.increment();

        // Calculate marketplace fee
        uint256 feeAmount = (item.price * marketplaceFee) / 10000;
        uint256 sellerAmount = item.price - feeAmount;

        // Transfer payment to seller
        payable(item.seller).transfer(sellerAmount);
        
        // Transfer fee to fee recipient
        if (feeAmount > 0) {
            payable(feeRecipient).transfer(feeAmount);
        }

        // Transfer NFT to buyer
        IERC721(item.nftContract).transferFrom(address(this), msg.sender, item.tokenId);

        // Refund excess payment
        if (msg.value > item.price) {
            payable(msg.sender).transfer(msg.value - item.price);
        }

        emit MarketItemSold(itemId, item.nftContract, item.tokenId, item.seller, msg.sender, item.price);
    }

    /**
     * @dev Place a bid on an auction item
     * @param itemId ID of the market item
     */
    function placeBid(uint256 itemId) 
        external 
        payable 
        nonReentrant 
        itemExists(itemId) 
        itemNotSold(itemId) 
        auctionActive(itemId) 
    {
        MarketItem storage item = idToMarketItem[itemId];
        require(msg.value > item.highestBid, "Bid must be higher than current highest bid");
        require(msg.sender != item.seller, "Seller cannot bid on own item");

        // Refund previous highest bidder
        if (item.highestBidder != address(0)) {
            userBids[itemId][item.highestBidder] += item.highestBid;
        }

        // Update highest bid
        item.highestBid = msg.value;
        item.highestBidder = msg.sender;
        userBids[itemId][msg.sender] = msg.value;

        // Add to bidders list if new bidder
        bool isNewBidder = true;
        for (uint256 i = 0; i < auctionBidders[itemId].length; i++) {
            if (auctionBidders[itemId][i] == msg.sender) {
                isNewBidder = false;
                break;
            }
        }
        if (isNewBidder) {
            auctionBidders[itemId].push(msg.sender);
        }

        emit BidPlaced(itemId, msg.sender, msg.value);
    }

    /**
     * @dev End an auction and transfer NFT to winner
     * @param itemId ID of the market item
     */
    function endAuction(uint256 itemId) 
        external 
        nonReentrant 
        itemExists(itemId) 
        itemNotSold(itemId) 
    {
        MarketItem storage item = idToMarketItem[itemId];
        require(item.isAuction, "Not an auction");
        require(block.timestamp >= item.auctionEndTime, "Auction not ended");
        require(item.highestBidder != address(0), "No bids placed");

        item.sold = true;
        item.owner = item.highestBidder;
        _itemsSold.increment();

        // Calculate marketplace fee
        uint256 feeAmount = (item.highestBid * marketplaceFee) / 10000;
        uint256 sellerAmount = item.highestBid - feeAmount;

        // Transfer payment to seller
        payable(item.seller).transfer(sellerAmount);
        
        // Transfer fee to fee recipient
        if (feeAmount > 0) {
            payable(feeRecipient).transfer(feeAmount);
        }

        // Transfer NFT to winner
        IERC721(item.nftContract).transferFrom(address(this), item.highestBidder, item.tokenId);

        emit AuctionEnded(itemId, item.highestBidder, item.highestBid);
        emit MarketItemSold(itemId, item.nftContract, item.tokenId, item.seller, item.highestBidder, item.highestBid);
    }

    /**
     * @dev Withdraw bid if auction is not won
     * @param itemId ID of the market item
     */
    function withdrawBid(uint256 itemId) external nonReentrant {
        MarketItem storage item = idToMarketItem[itemId];
        require(item.isAuction, "Not an auction");
        require(block.timestamp >= item.auctionEndTime, "Auction not ended");
        require(msg.sender != item.highestBidder, "Winner cannot withdraw bid");
        
        uint256 bidAmount = userBids[itemId][msg.sender];
        require(bidAmount > 0, "No bid to withdraw");
        
        userBids[itemId][msg.sender] = 0;
        payable(msg.sender).transfer(bidAmount);
    }

    /**
     * @dev Update item price
     * @param itemId ID of the market item
     * @param newPrice New price in wei
     */
    function updateItemPrice(uint256 itemId, uint256 newPrice) 
        external 
        onlyItemOwner(itemId) 
        itemNotSold(itemId) 
    {
        require(newPrice > 0, "Price must be greater than 0");
        require(!idToMarketItem[itemId].isAuction, "Cannot update price of auction item");
        
        idToMarketItem[itemId].price = newPrice;
        emit PriceUpdated(itemId, newPrice);
    }

    /**
     * @dev Cancel a market item
     * @param itemId ID of the market item
     */
    function cancelMarketItem(uint256 itemId) 
        external 
        onlyItemOwner(itemId) 
        itemNotSold(itemId) 
    {
        MarketItem storage item = idToMarketItem[itemId];
        
        // Refund all bidders if it's an auction
        if (item.isAuction) {
            for (uint256 i = 0; i < auctionBidders[itemId].length; i++) {
                address bidder = auctionBidders[itemId][i];
                uint256 bidAmount = userBids[itemId][bidder];
                if (bidAmount > 0) {
                    userBids[itemId][bidder] = 0;
                    payable(bidder).transfer(bidAmount);
                }
            }
        }
        
        // Transfer NFT back to seller
        IERC721(item.nftContract).transferFrom(address(this), item.seller, item.tokenId);
        
        // Mark as sold to prevent further operations
        item.sold = true;
        item.owner = item.seller;
    }

    /**
     * @dev Get market item details
     * @param itemId ID of the market item
     * @return MarketItem struct
     */
    function getMarketItem(uint256 itemId) external view returns (MarketItem memory) {
        return idToMarketItem[itemId];
    }

    /**
     * @dev Get all active market items
     * @return Array of active market items
     */
    function getActiveMarketItems() external view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 activeItemCount = 0;
        
        // Count active items
        for (uint256 i = 1; i <= itemCount; i++) {
            if (!idToMarketItem[i].sold) {
                activeItemCount++;
            }
        }
        
        // Create array of active items
        MarketItem[] memory activeItems = new MarketItem[](activeItemCount);
        uint256 currentIndex = 0;
        
        for (uint256 i = 1; i <= itemCount; i++) {
            if (!idToMarketItem[i].sold) {
                activeItems[currentIndex] = idToMarketItem[i];
                currentIndex++;
            }
        }
        
        return activeItems;
    }

    /**
     * @dev Set marketplace fee
     * @param newFee New fee percentage in basis points
     */
    function setMarketplaceFee(uint256 newFee) external onlyOwner {
        require(newFee <= MAX_MARKETPLACE_FEE, "Fee exceeds maximum");
        marketplaceFee = newFee;
    }

    /**
     * @dev Set fee recipient address
     * @param newFeeRecipient New fee recipient address
     */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "Invalid address");
        feeRecipient = newFeeRecipient;
    }

    /**
     * @dev Get total number of items
     * @return Total item count
     */
    function getTotalItems() external view returns (uint256) {
        return _itemIds.current();
    }

    /**
     * @dev Get total number of sold items
     * @return Total sold item count
     */
    function getTotalSoldItems() external view returns (uint256) {
        return _itemsSold.current();
    }
}
