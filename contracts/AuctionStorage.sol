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
import "./TokenEscrow.sol";

/// @title AuctionStorage.
/// @author @dhipgraby - OnChain Solutions.

/// @notice This is the storage contract containing all the global variables, custom errors, events,
contract AuctionStorage is
    ERC721Holder,
    Context,
    AccessControlEnumerable,
    ReentrancyGuard
{
    /// @notice Escrow contract that holds the seller funds and pendingReturns.
    /// @return escrow The Escrow contract address.
    Escrow public escrow;

    /// @notice TokenEscrow contract that holds seller ERC20 funds and pendingReturns.
    /// @return escrow The Escrow contract address.
    TokenEscrow public tokenEscrow;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes4 internal constant _INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 internal constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    bytes4 private constant _INTERFACE_ID_ERC20 = 0x36372b07;
    uint16 public serviceFee;

    /// ------------------------------- SUMMARY -------------------------------
    /// --------------- MODIFIERS -------------------
    /// --------------- STRUCTS ---------------------
    /// --------------- EVENTS ----------------------
    /// --------------- MAPPINGS --------------------
    /// --------------- CUSTOM ERRORS ---------------
    /// --------------- FUNCTIONS -------------------

    // region ------------------------------- MODIFIERS -------------------------------

    /// @dev Modifier will validate if the caller is authorized.
    /// @param itemId The tokenId of the nft to validate.
    modifier isAuthorized(uint256 itemId, address nftContract) {
        if (_msgSender() != IERC721(nftContract).ownerOf(itemId))
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
        if (msg.value <= _auction.highestBid)
            revert LowValue(_auction.highestBid);
        _;
    }

    modifier tokenCosts(bytes32 id, uint256 amount) {
        MarketAuction memory _auction = auctionsMapping[id];
        if (amount <= _auction.highestBid) revert LowAmount(_auction.highestBid,amount);
        _;
    }

    /// @notice Modifier will validate that the auctionId is a live auction.
    /// @param auctionId The id of the auction to bid on.
    modifier isLiveAuction(bytes32 auctionId) {
        MarketAuction memory _a = auctionsMapping[auctionId];
        if (_a.ended) revert NotActive(_a.auctionId);
        _;
    }

    /// @dev Modifier will validate if the caller is the seller.
    /// @param seller The account to validate.
    modifier isAuth(address payable seller) {
        if (seller != _msgSender()) revert NotAuth();
        _;
    }

    modifier supportsERC20(address contractAddress) {
        if(!IERC165(contractAddress).supportsInterface(_INTERFACE_ID_ERC20)) revert tokenNotSupported();
        _;
    }

    // endregion

    // region ------------------------------- STRUCTS -------------------------------

    struct MarketAuction {
        bytes32 auctionId;
        uint256 itemId;
        uint256 auctionEndTime;
        uint256 highestBid;
        address nftContract;
        address ERC20Contract;
        address highestBidder;
        address payable seller;
        bool isERC20;
        bool ended;
    }

    // endregion

    // region ------------------------------- EVENTS -------------------------------

    /// @notice Emitted when a new timed auction is created.
    /// @param auctionId Indexed - The auction Id.
    /// @param seller Indexed - The seller of this nft.
    event MarketAuctionCreated(
        bytes32 indexed auctionId,
        address indexed seller
    );

    /// @notice Emitted when a item has been sold and funds are deposited into escrow.
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

    /// @notice Emitted on deployment, escrow is deployed by the constructor .
    /// @param escrow Indexed - The contract address of the escrow.
    /// @param operator Indexed - The account authorized to interact with the escrow contract.
    event EscrowDeployed(
        Escrow indexed escrow,
        TokenEscrow indexed tokenEscrow,
        address indexed operator
    );

    /// @notice Emitted on withdrawals from the escrow contract.
    /// @param seller Indexed - The receiver of the funds.
    event WithdrawFromEscrow(address indexed seller);

    /// @notice Emitted on withdrawals from the pending returns in escrow.
    /// @param to Indexed - The receiver of the funds.
    /// @param amount The withdraw amount.
    event WithdrawPendingReturns(address indexed to, uint256 amount);

    /// @notice Emitted when an auction is not sold.
    /// @param auctionId Indexed - The auctionId.
    /// @param itemId Indexed - The itemId of this auction.
    event NoBuyer(bytes32 indexed auctionId, uint256 indexed itemId);

    /// @notice Emitted when an auction is removed.
    /// @param auctionId Indexed - The auctionId.
    /// @param itemId Indexed - The itemId of this auction.
    /// @param highestBidder Indexed - The winner of the auction.
    /// @param highestBid The highestBid of this auction.
    /// @param timestamp The timestamp when this event was emitted.
    event AuctionRemoved(
        bytes32 indexed auctionId,
        uint256 indexed itemId,
        address indexed highestBidder,
        uint256 highestBid,
        uint256 timestamp
    );

    /// @notice Emitted when the serviceFee transaction is completed.
    /// @param serviceWallet Indexed - The account to receive the fee amount.
    /// @param amount The transacted fee amount.
    event TransferServiceFee(address indexed serviceWallet, uint256 amount);

    /// @notice Emitted when an auction is claimed.
    /// @param auctionId Indexed - The auctionId.
    /// @param itemId Indexed - The itemId of this auction.
    /// @param winner Indexed - The winner of the auction.
    /// @param amount The amount of the bid.
    event AuctionClaimed(
        bytes32 indexed auctionId,
        uint256 indexed itemId,
        address indexed winner,
        uint256 amount
    );

    /// @notice Emitted after an asset has been purchased and transfered to the new owner
    /// @param to Indexed - The receiver of the ntf.
    /// @param collection Indexed - The NFT smart contract address.
    /// @param tokenId Indexed - The tokenId.
    event AssetSent(
        address indexed to,
        address indexed collection,
        uint256 indexed tokenId
    );

    /// @notice Emitted when the serviceFee transaction is completed.
    /// @param receiver Indexed - The account to receive the royalty amount.
    /// @param amount The transacted royalty amount.
    event TransferRoyalty(address indexed receiver, uint256 amount);

    // endregion

    // region ------------------------------- MAPPINGS -------------------------------

    /// @notice Maps auctionsIds with MarketAuction struct.
    mapping(bytes32 => MarketAuction) public auctionsMapping;

    /// @notice Maps address and tokien id to check inAuction
    mapping(address => mapping(uint256 => bool)) public isActiveTokenId;

    /// @notice Maps user address to ether amount in pendingReturns.
    mapping(address => uint256) public pendingReturns;

    /// @notice Maps user address to ERC20 token amount in pendingFunds.
    mapping(address => mapping(address => uint256)) public pendingFunds;

    // endregion

    // region ------------------------------- CUSTOM ERRORS -------------------------------

    /// @notice Thrown if caller is not authorized or owner of the token.
    error NotTokenOwner();

    /// @notice Thrown if bidder is seller.
    error bidderIsSeller();

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

    /// @notice Thrown if the Token amount is to low to transact.
    /// @param expected The expected value.
    /// @param amount The current value.
    error LowAmount(uint256 expected,uint256 amount);

    /// @notice Thrown if not active auction
    /// @param id The Id of the Item.
    error NotActive(bytes32 id);

    /// @notice Thrown if caller is not authorized.
    error NotAuth();

    /// @notice Thrown if caller is not approve.
    error notApproved();

    /// @notice Thrown with a string message.
    /// @param failed Error message string describes what transaction failed.
    error FailedTransaction(string failed);

    error transferFunds();

    error transferRoyaltiesFunds();

    /// @notice Thrown error if ERC20 token address is not supported.
    error tokenNotSupported();

    error funsNotTransfered();

    // endregion

    // region ------------------------------- FUNCTIONS -------------------------------

    /// @notice Internal method used to deposit the salesAmount into the Escrow contract.
    /// @param tokenOwner The address of the seller.
    /// @param value The priceInWei of the listed order.
    function _sendPaymentToEscrow(address payable tokenOwner, uint256 value)
        internal
    {
        escrow.deposit{value: value}(tokenOwner);
        emit DepositToEscrow(tokenOwner, value);
    }

    /// @notice Internal method used to deposit the salesAmount into the TokenEscrow contract.
    /// @param tokenContract The address of ERC20 contract.
    /// @param amount The amount of the listed order.
    function _sendPaymentToTokenEscrow(
        address payable userAddress,
        address tokenContract,
        uint256 amount
    ) internal returns (bool) {
          bool success = IERC20(tokenContract).transferFrom(
            userAddress,
            address(tokenEscrow),
            amount
        );        
        return success;
    }

    /// @notice Allows a seller to withdraw their sales revenue from the escrow contract.
    /// @param seller The seller of the item.
    /// @dev Only the seller can check their own escrowed balance.
    function withdrawSellerRevenue(address payable seller)
        public
        isAuth(seller)
    {
        _withdrawFromEscrow(seller);
    }

    /// @notice Internal method used to withdraw the salesAmount from the Escrow contract.
    /// @param seller The address of the seller.
    /// @dev Will also reset pendingReturn to 0.
    function _withdrawFromEscrow(address payable seller) internal {
        pendingReturns[seller] = 0;
        escrow.withdraw(seller);
        emit WithdrawFromEscrow(seller);
    }

    /// @notice Allows a seller to withdraw their sales revenue from the escrow contract.
    /// @param seller The seller of the item.
    /// @dev Only the seller can check their own escrowed balance.
    function withdrawSellerFunds(address payable seller, address tokenContract)
        public
        isAuth(seller)
        returns (bool)
    {
        bool success = _withdrawFromTokenEscrow(seller, tokenContract);
        return success;
    }

    /// @notice Internal method used to withdraw the salesAmount from the TokenEscrow contract.
    /// @param tokenContract The address of the ERC20 contract.
    /// @dev Will also reset pendingReturn to 0.
    function _withdrawFromTokenEscrow(address seller, address tokenContract)
        internal
        returns (bool)
    {
        pendingFunds[tokenContract][_msgSender()] = 0;
        bool success = tokenEscrow.withdraw(seller, tokenContract);
        return success;
    }

    /// @notice Internal method used to send the nft asset to the new token Owner.
    /// @param auctionId The current auction to retrive data from.
    /// @param receiver The address to receiver the nft.
    function _sendAsset(bytes32 auctionId, address receiver) internal {
        IERC721(auctionsMapping[auctionId].nftContract).safeTransferFrom(
            auctionsMapping[auctionId].seller,
            receiver,
            auctionsMapping[auctionId].itemId
        );

        emit AssetSent(
            receiver,
            auctionsMapping[auctionId].nftContract,
            auctionsMapping[auctionId].itemId
        );
    }

    /// @notice Method used to calculate the serviceFee to transfer.
    /// @param _priceInWei the salesPrice.
    /// @return sellerAmount The amount to send to the seller.
    /// @return totalFeeAmount Includes service fee seller side, and service fee buyer side.
    function _calculateFees(uint256 _priceInWei)
        internal
        view
        returns (uint256 sellerAmount, uint256 totalFeeAmount)
    {
        uint256 serviceFeeAmount = (serviceFee * _priceInWei) / 10000;
        totalFeeAmount = (serviceFeeAmount * 2);
        sellerAmount = (_priceInWei - totalFeeAmount);
        return (sellerAmount, totalFeeAmount);
    }

    function rescue(
        address collection,
        uint256[] calldata tokenIds,
        address receiver
    ) external onlyRole(ADMIN_ROLE) {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(collection).safeTransferFrom(
                address(this),
                receiver,
                tokenIds[i]
            );
        }
    }

    /// @notice Internal method used to transfer the royalties and service fee.
    function _transferRoyaltiesAndFunds(bytes32 auctionId)
        internal
        returns (bool)
    {
        MarketAuction memory currentAuction = auctionsMapping[auctionId];

        (address _royaltyReceiver, uint256 _royaltyAmount) = IERC2981(
            currentAuction.nftContract
        ).royaltyInfo(currentAuction.itemId, currentAuction.highestBid);

        uint256 _toSeller = (currentAuction.highestBid - _royaltyAmount);

        if (currentAuction.isERC20) {
            bool _success = IERC20(currentAuction.ERC20Contract).transfer(
                currentAuction.seller,
                _toSeller
            );
            if (!_success) revert FailedTransaction("Funds");

            bool _s = IERC20(currentAuction.ERC20Contract).transfer(
                _royaltyReceiver,
                _royaltyAmount
            );
            if (!_s) revert FailedTransaction("Royalty");
        } else {
            (bool _success, ) = currentAuction.seller.call{value: _toSeller}(
                ""
            );
            if (!_success) revert FailedTransaction("Funds");

            (bool _s, ) = _royaltyReceiver.call{value: _royaltyAmount}("");
            if (!_s) revert FailedTransaction("Royalty");
        }

        return true;
    }

    /// @notice Internal method used to transfer the highestBid amount to seller.
    function _transferFunds(bytes32 auctionId) internal returns (bool) {
        MarketAuction memory item = auctionsMapping[auctionId];

        uint256 _toSeller = item.highestBid;

        (bool _success, ) = item.seller.call{value: _toSeller}("");
        if (!_success) revert FailedTransaction("Funds");
        return true;
    }

    /// @notice Internal method used to transfer the highestBid amount to seller.
    function _transferTokenFunds(bytes32 auctionId) internal returns (bool) {
        MarketAuction memory item = auctionsMapping[auctionId];

        uint256 _toSeller = item.highestBid;

        bool _success = IERC20(item.ERC20Contract).transfer(
            _msgSender(),
            _toSeller
        );
        if (!_success) revert FailedTransaction("Funds");
        return true;
    }

    function getBalance(address account) public view returns (uint256) {
        return account.balance;
    }

    // endregion
}
