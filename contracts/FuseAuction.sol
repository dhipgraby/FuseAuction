///SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./AuctionStorage.sol";

contract FuseAuction is AuctionStorage {
    uint256 internal _currentAuctionId;
    uint256 internal _currentAuctionsSold;

    receive() external payable {
        revert ErrorMessage("Not payable receive");
    }

    constructor() {
        escrow = new Escrow();

        serviceFee = 200;

        emit EscrowDeployed(escrow, address(this));
    }

    /// @notice Creates a new Auction from a given market item.    
    /// @dev Restricted by modifiers { isAuthorized, isNotActive,isApprovedOrApprovedForAll }.
    function createMarketAuction(MarketAuctionInput calldata input)
        public
        isAuthorized(input.itemId, input.nftContract, input.seller)
        isNotActive(input.itemId, input.nftContract)
        isApprovedOrApprovedForAll(
            input.itemId,
            input.nftContract,
            input.seller
        )
        returns (bytes32 _auctionId)
    {
        if (input.biddingTime == 0 || input.minimumBid == 0) {
            revert NoZeroValues();
        }

        _auctionId = bytes32(_currentAuctionId += 1);

        MarketAuction storage _a = auctionsMapping[_auctionId];
        _a.itemId = input.itemId;
        _a.auctionEndTime = block.timestamp + input.biddingTime;
        _a.highestBid = input.minimumBid;
        _a.nftContract = input.nftContract;
        _a.seller = input.seller;
        _a.ended = false;

        isActiveTokenId[input.nftContract][input.itemId] = true;

        emit MarketAuctionCreated(_auctionId, input.seller);

        return _auctionId;
    }

    /// @notice Executes a new bid on a auctionId.
    /// @param auctionId The auctionId to bid on.
    /// @dev Restricted by modifiers { costs, isLiveAuction, minBid }.
    function bid(bytes32 auctionId)
        public
        payable
        costs(auctionId)
        isLiveAuction(auctionId)
        minBid(auctionId)
    {
        MarketAuction storage _a = auctionsMapping[auctionId];
        uint256 _bid = msg.value;
        address payable _bidder = payable(_msgSender());

        if (_msgSender() == _a.highestBidder)
            revert ErrorMessage("Already highest bidder!");

        if (_a.highestBidder != address(0)) {
            pendingReturns[_a.highestBidder] += _a.highestBid;
            _sendPaymentToEscrow(payable(_a.highestBidder), _a.highestBid);
        }

        _a.highestBid = _bid;
        _a.highestBidder = _bidder;

        emit HighestBidIncrease(_a.auctionId, _a.highestBidder, _a.highestBid);
    }

    /// @notice Method used to fetch all current live timed auctions on the marketplace.
    /// @return MarketAuction Returns an bytes32 array of all the current active auctions.
    function fetchMarketAuctions()
        external
        view
        returns (MarketAuction[] memory)
    {
        uint256 auctionCount = _currentAuctionId;
        uint256 unsoldAuctionCount = _currentAuctionId - _currentAuctionsSold;
        uint256 currentIndex = 0;

        MarketAuction[] memory _auctions = new MarketAuction[](
            unsoldAuctionCount
        );
        for (uint256 i = 0; i < auctionCount; i++) {
            bytes32 currentId = bytes32(i + 1);
            MarketAuction memory currentAuction = auctionsMapping[currentId];
            _auctions[currentIndex] = currentAuction;
            currentIndex += 1;
        }
        return _auctions;
    }

    /// @notice For users who lost an auction.This will allow them to withdraw their pending returns from the escrow.
    /// @dev This method will withdraw all the users funds from the escrow contract.
    /// @return success if transaction is completed succewssfully.
    function withdrawPendingReturns() external returns (bool success) {
        if (pendingReturns[_msgSender()] == 0)
            revert ErrorMessage("No pending Returns!");

        uint256 _amount = pendingReturns[_msgSender()];

        if (_amount > 0) {
            pendingReturns[_msgSender()] = 0;

            withdrawSellerRevenue(payable(_msgSender()));
            emit WithdrawPendingReturns(_msgSender(), _amount);
        }
        return true;
    }

    /// @notice Public method to finalise an auction.
    /// @param auctionId The auctionId to claim.
    /// @dev The winner of an auction is able to end the auction they won, by claiming the auction,
    ///      the winner will receive their nft and the payment is transfered to the escrow contract.
    /// @return bool Returns true is auction has a highest bidder, returns false if the auction had no bids.
    function claimAuction(bytes32 auctionId)
        public
        isLiveAuction(auctionId)
        returns (bool)
    {
        MarketAuction storage _a = auctionsMapping[auctionId];

        if (block.timestamp < _a.auctionEndTime)
            revert ErrorMessage("To soon!");
        if (_a.ended) revert NotActive(_a.auctionId);

        _a.ended = true;
        isActiveTokenId[_a.nftContract][_a.itemId] = false;

        if (_a.highestBidder == address(0)) {
            _removeAuction(_a.auctionId);
            emit NoBuyer(_a.auctionId, _a.itemId);
            return false;
        }

        _currentAuctionsSold += 1;

        bool success = IERC165(_a.nftContract).supportsInterface(
            _INTERFACE_ID_ERC2981
        );

        if (!success) {
            _sendPaymentToEscrow(_a.seller, _a.highestBid);
            _sendAsset(auctionId, _a.highestBidder);
        } else {
            _sendAsset(auctionId, _a.highestBidder);
        }

        emit AuctionClaimed(
            _a.auctionId,
            _a.itemId,
            _a.highestBidder,
            _a.highestBid
        );

        _removeAuction(_a.auctionId);

        return true;
    }

    /// @notice Private method to remove a auction from the auctionsMapping.
    /// @param auctionId The auctionId to remove.
    function _removeAuction(bytes32 auctionId) private {
        MarketAuction memory _a = auctionsMapping[auctionId];
        if (_a.ended) {
            emit AuctionRemoved(
                _a.auctionId,
                _a.itemId,
                _a.highestBidder,
                _a.highestBid,
                block.timestamp
            );

            delete (auctionsMapping[auctionId]);
        }
    }

    /// @notice Method to get an marketAuction.
    /// @param auctionId The bytes32 auctionId to query.
    /// @return marketAuction Returns the MarketAuction.
    function getMarketAuction(bytes32 auctionId)
        external
        view
        onlyRole(ADMIN_ROLE)
        returns (MarketAuction memory marketAuction)
    {
        MarketAuction memory a = auctionsMapping[auctionId];
        return a;
    }
}
