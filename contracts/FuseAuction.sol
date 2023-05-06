///SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./AuctionStorage.sol";

contract FuseAuction is AuctionStorage {
    uint256 internal _currentAuctionId;
    uint256 internal _currentAuctionsSold;

    receive() external payable {
        revert ErrorMessage("Not payable receive");
    }

    /// @notice Creates a new Auction from a given market item.
    /// @param itemId The Id of the MarketItem to list for auction.
    /// @param biddingTime The timespan in seconds to collect bids for this auction.
    /// @param minimumBid The minimum bid amount for this auction.
    /// @dev Restricted to only owner account.
    /// @dev Restricted by modifiers { isAuthorized, isNotActive }.
    function createMarketAuction(
    uint256 itemId,
    uint256 biddingTime,
    uint256 minimumBid,
    address nftContract,
    address payable seller
)
    public
    isAuthorized(itemId, nftContract, seller)
    isNotActive(itemId, nftContract)
    returns (bytes32 _auctionId)
{
    if (biddingTime == 0 || minimumBid == 0) {
        revert NoZeroValues();
    }

    _auctionId = bytes32(_currentAuctionId += 1);    

    MarketAuction storage _a = auctionsMapping[_auctionId];
    _a.auctionId = _auctionId;
    _a.itemId = itemId;
    _a.auctionEndTime = block.timestamp + biddingTime;
    _a.highestBid = minimumBid;
    _a.highestBidder;
    _a.seller = payable(seller);
    _a.ended = false;

    isActiveTokenId[nftContract][itemId] = true;

    emit MarketAuctionCreated(
        _auctionId,
        seller
    );

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

        if (_msgSender() == _a.highestBidder) revert ErrorMessage("Already highest bidder!");
        if (two != false) revert ErrorMessage("Requires uint value: 2");

        if (_a.highestBidder != address(0)) {
            pendingReturns[_a.highestBidder] += _a.highestBid;
            _sendPaymentToEscrow(payable(_a.highestBidder), _a.highestBid);
        }

        _a.highestBid = _bid;
        _a.highestBidder = _bidder;

        emit HighestBidIncrease(_a.auctionId, _a.highestBidder, _a.highestBid);
    }


}
