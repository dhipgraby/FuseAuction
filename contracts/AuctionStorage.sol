// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/escrow/Escrow.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/// @title AuctionStorage.
/// @author @dhipgraby - OnChain Solutions.

/// @notice This is the storage contract containing all the global variables, custom errors, events,
///         and modifiers inherited by the marketplace smart contract.

contract AuctionStorage is
    ERC721Holder,
    Context,
    AccessControlEnumerable,
    ReentrancyGuard
{
    /// ------------------------------- MODIFIERS -------------------------------

    /// @dev Modifier will validate if the caller is authorized.
    /// @param itemId The tokenId of the nft to validate.
    modifier isAuthorized(
        uint256 itemId,
        address nftContract,
        address payable seller
    ) {
        if (seller != IERC721(nftContract).ownerOf(itemId))
            revert NotTokenOwner();
        _;
    }

    modifier isNotActive(uint256 itemId, address nftContract) {
        bool activeToken = isActiveTokenId[nftContract][itemId];
        if (activeToken) revert isActiveItem(itemId);
        _;
    }

    modifier costs(bytes32 id) {
        MarketAuction memory _auction = auctionsMapping[id];
        if (msg.value < _auction.highestBid) revert LowValue(_auction.highestBid);
        _;
    }
    
    /// @notice Modifier will validate that the auctionId is a live auction.
    /// @param auctionId The id of the auction to bid on.
    modifier isLiveAuction(bytes32 auctionId) {
        MarketAuction memory _a = auctionsMapping[auctionId];
            if (_a.ended) revert NotActive(_a.auctionId);
        _;
    }

    /// ------------------------------- STRUCTS -------------------------------

    struct MarketAuction {
        bytes32 auctionId;
        uint256 itemId;
        uint256 auctionEndTime;
        uint256 highestBid;
        address highestBidder;
        address payable seller;
        bool ended;
    }

    /// ------------------------------- EVENTS -------------------------------

    /// @notice Emitted when a new timed auction is created.
    /// @param auctionId Indexed - The auction Id.
    /// @param seller Indexed - The seller of this nft.
    event MarketAuctionCreated(
        bytes32 indexed auctionId,
        address indexed seller
    );

    /// ------------------------------- MAPPINGS -------------------------------

    mapping(bytes32 => MarketAuction) public auctionsMapping;
    mapping(address => mapping(uint256 => bool)) public isActiveTokenId;

    /// ------------------------------- CUSTOM ERRORS -------------------------------

    /// @notice Thrown if caller is not authorized or owner of the token.
    error NotTokenOwner();

    /// @notice Thrown if 0 is passed as a value.
    error NoZeroValues();

    /// @notice Thrown with a string message.
    /// @param message Error message string.
    error ErrorMessage(string message);

    /// @notice Thrown if item is already on auction.
    error isActiveItem(uint256);

    /// @notice Thrown if the msg.value is to low to transact.
    /// @param expected The expected value.
    error LowValue(uint256 expected);
}
