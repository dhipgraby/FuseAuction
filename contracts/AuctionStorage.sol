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
///         and modifiers inherited by the FuseAuction smart contract.

contract AuctionStorage is
    ERC721Holder,
    Context,
    AccessControlEnumerable,
    ReentrancyGuard
{
    /// @notice Escrow contract that holds the seller funds and pendingReturns.
    /// @return escrow The Escrow contract address.
    Escrow public escrow;

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
        if (msg.value < _auction.highestBid)
            revert LowValue(_auction.highestBid);
        _;
    }

    /// @notice Modifier will validate that the auctionId is a live auction.
    /// @param auctionId The id of the auction to bid on.
    modifier isLiveAuction(bytes32 auctionId) {
        MarketAuction memory _a = auctionsMapping[auctionId];
        if (_a.ended) revert NotActive(_a.auctionId);
        _;
    }

    /// @dev Modifier will validate that the bid is above current highest bid.
    /// @param auctionId The id of the auction to bid on.
    modifier minBid(bytes32 auctionId) {
        MarketAuction memory a = auctionsMapping[auctionId];
        if (msg.value <= a.highestBid) revert LowValue(a.highestBid);
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

    /// @notice Emitted when a market item has been sold and funds are deposited into escrow.
    /// @param seller Indexed - The receiver of the funds.
    /// @param value The salesprice of the nft, minus the servicefee and royalty amount.
    event DepositToEscrow(address indexed seller, uint256 value);

    /// @notice Emitted when a higher bid is registered for an auction.
    /// @param auctionId Indexed - The auctionId.
    /// @param bidder Indexed - The receiver of the funds.
    /// @param amount The amount of the bid.
    event HighestBidIncrease(
        bytes32 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );

    /// @notice Emitted on marketplace deployment, escrow is deployed by the constructor .
    /// @param escrow Indexed - The contract address of the escrow.
    /// @param operator Indexed - The account authorized to interact with the escrow contract.
    event EscrowDeployed(Escrow indexed escrow, address indexed operator);

    /// ------------------------------- MAPPINGS -------------------------------

    /// @notice Maps auctionsIds with MarketAuction struct.
    mapping(bytes32 => MarketAuction) public auctionsMapping;

    /// @notice Maps address and tokien id to check inAuction
    mapping(address => mapping(uint256 => bool)) public isActiveTokenId;

    /// @notice Maps user address to amount in pendingReturns.
    mapping(address => uint256) public pendingReturns;

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

    /// @notice Thrown if the marketItem is not an active market item.
    /// @param id The Id of the market Item.
    error NotActive(bytes32 id);

    /// ------------------------------- FUNCTIONS -------------------------------

    /// @notice Internal method used to deposit the salesAmount into the Escrow contract.
    /// @param tokenOwner The address of the seller of the MarketOrder.
    /// @param value The priceInWei of the listed order.
    function _sendPaymentToEscrow(address payable tokenOwner, uint256 value)
        internal
    {
        escrow.deposit{value: value}(tokenOwner);
        emit DepositToEscrow(tokenOwner, value);
    }
}
