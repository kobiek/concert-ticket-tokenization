// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title ConcertTicketNFT
 * @dev ERC-721 NFT contract for concert tickets with fractional ownership capabilities
 */
contract ConcertTicketNFT is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using ECDSA for bytes32;

    Counters.Counter private _tokenIdCounter;

    // Struct to store ticket information
    struct TicketInfo {
        string eventId;           // Unique event identifier
        string eventName;         // Human-readable event name
        string venue;             // Venue name
        string seatInfo;          // Seat/section information
        uint256 eventDate;        // Unix timestamp of event
        uint256 originalPrice;    // Original ticket price in wei
        uint256 tokenPrice;       // Current token price in wei
        bool isFractional;        // Whether ticket can be fractionally owned
        uint256 totalFractions;   // Total number of fractions (if fractional)
        address originalOwner;    // Address of original ticket purchaser
        bool isTransferable;      // Whether ticket can be transferred
        bool isUsed;              // Whether ticket has been used for entry
        string metadataURI;       // IPFS URI for additional metadata
        uint256 createdAt;        // Block timestamp when created
    }

    // Mapping from token ID to ticket information
    mapping(uint256 => TicketInfo) public tickets;
    
    // Mapping from event ID to array of token IDs
    mapping(string => uint256[]) public eventTickets;
    
    // Mapping to track fractional ownership
    mapping(uint256 => mapping(address => uint256)) public fractionalOwnership;
    
    // Mapping to track ticket usage (prevent double-spending)
    mapping(uint256 => bool) public usedTickets;
    
    // Events
    event TicketMinted(
        uint256 indexed tokenId,
        string indexed eventId,
        address indexed owner,
        uint256 price,
        bool isFractional
    );
    
    event TicketTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 price
    );
    
    event TicketUsed(
        uint256 indexed tokenId,
        address indexed user,
        uint256 timestamp
    );
    
    event FractionalOwnershipUpdated(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 amount
    );

    // Modifiers
    modifier onlyTicketOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not the ticket owner");
        _;
    }
    
    modifier ticketNotUsed(uint256 tokenId) {
        require(!tickets[tokenId].isUsed, "Ticket already used");
        _;
    }
    
    modifier validFractionAmount(uint256 tokenId, uint256 amount) {
        require(tickets[tokenId].isFractional, "Ticket not fractional");
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= tickets[tokenId].totalFractions, "Amount exceeds total fractions");
        _;
    }

    constructor() ERC721("ConcertTicket", "CTKT") {}

    /**
     * @dev Mint a new concert ticket NFT
     * @param to Address to mint the ticket to
     * @param eventId Unique event identifier
     * @param eventName Human-readable event name
     * @param venue Venue name
     * @param seatInfo Seat/section information
     * @param eventDate Unix timestamp of event
     * @param price Original ticket price in wei
     * @param isFractional Whether ticket can be fractionally owned
     * @param totalFractions Total number of fractions (if fractional)
     * @param metadataURI IPFS URI for additional metadata
     */
    function mintTicket(
        address to,
        string memory eventId,
        string memory eventName,
        string memory venue,
        string memory seatInfo,
        uint256 eventDate,
        uint256 price,
        bool isFractional,
        uint256 totalFractions,
        string memory metadataURI
    ) external onlyOwner returns (uint256) {
        require(bytes(eventId).length > 0, "Event ID cannot be empty");
        require(eventDate > block.timestamp, "Event date must be in the future");
        require(price > 0, "Price must be greater than 0");
        
        if (isFractional) {
            require(totalFractions > 1, "Fractional tickets must have more than 1 fraction");
        }

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        tickets[tokenId] = TicketInfo({
            eventId: eventId,
            eventName: eventName,
            venue: venue,
            seatInfo: seatInfo,
            eventDate: eventDate,
            originalPrice: price,
            tokenPrice: price,
            isFractional: isFractional,
            totalFractions: totalFractions,
            originalOwner: to,
            isTransferable: true,
            isUsed: false,
            metadataURI: metadataURI,
            createdAt: block.timestamp
        });

        eventTickets[eventId].push(tokenId);
        
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, metadataURI);

        emit TicketMinted(tokenId, eventId, to, price, isFractional);
        
        return tokenId;
    }

    /**
     * @dev Transfer fractional ownership of a ticket
     * @param tokenId Token ID of the ticket
     * @param to Address to transfer fractions to
     * @param amount Number of fractions to transfer
     */
    function transferFractionalOwnership(
        uint256 tokenId,
        address to,
        uint256 amount
    ) external onlyTicketOwner(tokenId) validFractionAmount(tokenId, amount) {
        require(fractionalOwnership[tokenId][msg.sender] >= amount, "Insufficient fractional ownership");
        
        fractionalOwnership[tokenId][msg.sender] -= amount;
        fractionalOwnership[tokenId][to] += amount;
        
        emit FractionalOwnershipUpdated(tokenId, msg.sender, fractionalOwnership[tokenId][msg.sender]);
        emit FractionalOwnershipUpdated(tokenId, to, fractionalOwnership[tokenId][to]);
    }

    /**
     * @dev Mark a ticket as used (for entry verification)
     * @param tokenId Token ID of the ticket
     * @param signature Signature from authorized verifier
     */
    function useTicket(uint256 tokenId, bytes memory signature) 
        external 
        onlyTicketOwner(tokenId) 
        ticketNotUsed(tokenId) 
    {
        // Verify signature from authorized verifier
        bytes32 messageHash = keccak256(abi.encodePacked(tokenId, msg.sender, block.timestamp));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address signer = ethSignedMessageHash.recover(signature);
        
        require(isAuthorizedVerifier(signer), "Invalid verifier signature");
        
        tickets[tokenId].isUsed = true;
        usedTickets[tokenId] = true;
        
        emit TicketUsed(tokenId, msg.sender, block.timestamp);
    }

    /**
     * @dev Update ticket price
     * @param tokenId Token ID of the ticket
     * @param newPrice New price in wei
     */
    function updateTicketPrice(uint256 tokenId, uint256 newPrice) 
        external 
        onlyTicketOwner(tokenId) 
    {
        require(newPrice > 0, "Price must be greater than 0");
        tickets[tokenId].tokenPrice = newPrice;
    }

    /**
     * @dev Get ticket information
     * @param tokenId Token ID of the ticket
     * @return TicketInfo struct containing all ticket data
     */
    function getTicketInfo(uint256 tokenId) external view returns (TicketInfo memory) {
        return tickets[tokenId];
    }

    /**
     * @dev Get all tickets for an event
     * @param eventId Event identifier
     * @return Array of token IDs for the event
     */
    function getEventTickets(string memory eventId) external view returns (uint256[] memory) {
        return eventTickets[eventId];
    }

    /**
     * @dev Get fractional ownership for a user
     * @param tokenId Token ID of the ticket
     * @param user User address
     * @return Number of fractions owned by user
     */
    function getFractionalOwnership(uint256 tokenId, address user) external view returns (uint256) {
        return fractionalOwnership[tokenId][user];
    }

    /**
     * @dev Check if address is authorized verifier
     * @param verifier Address to check
     * @return True if authorized verifier
     */
    function isAuthorizedVerifier(address verifier) public view returns (bool) {
        // This would be implemented with a mapping of authorized verifiers
        // For now, returning true for demonstration
        return true;
    }

    /**
     * @dev Override transfer function to include price tracking
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        
        if (from != address(0) && to != address(0)) {
            emit TicketTransferred(tokenId, from, to, tickets[tokenId].tokenPrice);
        }
    }

    // Required overrides
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
