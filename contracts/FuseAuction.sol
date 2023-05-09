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
        serviceFee = 200;
        escrow = new Escrow();
        tokenEscrow = new TokenEscrow();
        emit EscrowDeployed(escrow, tokenEscrow, address(this));
    }

    /// @notice Creates a Native token Auction from a given item id.
    /// @dev Restricted by modifiers { isAuthorized, isNotActive }.
    function createNativeAuction(
        uint256 itemId,
        uint256 biddingTime,
        uint256 minimumBid,
        address nftContract
    )
        public
        isAuthorized(itemId, nftContract)
        isNotActive(itemId, nftContract)
        returns (bytes32 _auctionId)
    {
        if (biddingTime == 0 || minimumBid == 0) {
            revert NoZeroValues();
        }

        _auctionId = bytes32(_currentAuctionId += 1);

        MarketAuction storage _a = auctionsMapping[_auctionId];
        _a.itemId = itemId;
        _a.auctionEndTime = block.timestamp + biddingTime;
        _a.highestBid = minimumBid;
        _a.nftContract = nftContract;
        _a.seller = payable(_msgSender());
        _a.ended = false;

        isActiveTokenId[nftContract][itemId] = true;

        emit MarketAuctionCreated(_auctionId, _msgSender());

        return _auctionId;
    }

    /// @notice Creates a ERC20 token Auction from a given item id.
    /// @dev Restricted by modifiers { isAuthorized, isNotActive }.
    function createERC20Auction(
        uint256 itemId,
        uint256 biddingTime,
        uint256 minimumBid,
        address nftContract,
        address tokenAdrress
    )
        public
        isAuthorized(itemId, nftContract)
        isNotActive(itemId, nftContract)
        returns (bytes32 _auctionId)
    {
        if (biddingTime == 0 || minimumBid == 0) {
            revert NoZeroValues();
        }

        _auctionId = bytes32(_currentAuctionId += 1);

        MarketAuction storage _a = auctionsMapping[_auctionId];
        _a.itemId = itemId;
        _a.auctionEndTime = block.timestamp + biddingTime;
        _a.highestBid = minimumBid;
        _a.nftContract = nftContract;
        _a.ERC20Contract = tokenAdrress;
        _a.seller = payable(_msgSender());
        _a.isERC20 = true;
        _a.ended = false;

        isActiveTokenId[nftContract][itemId] = true;

        emit MarketAuctionCreated(_auctionId, _msgSender());

        return _auctionId;
    }

    /// @notice Executes a new bid on a auctionId.
    /// @param auctionId The auctionId to bid on.
    /// @dev Restricted by modifiers { costs, isLiveAuction }.
    function bid(
        bytes32 auctionId
    ) public payable costs(auctionId) isLiveAuction(auctionId) {
        MarketAuction storage _a = auctionsMapping[auctionId];
        if (_a.seller == _msgSender()) revert bidderIsSeller();

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

    /// @notice Executes a new bid on a auctionId.
    /// @param auctionId The auctionId to bid on.
    /// @dev Restricted by modifiers { costs, isLiveAuction }.
    function bidERC20(
        bytes32 auctionId,
        uint256 bidAmount
    ) public payable tokenCosts(auctionId, bidAmount) isLiveAuction(auctionId) {
        MarketAuction storage _a = auctionsMapping[auctionId];

        if (!_a.isERC20) revert tokenNotSupported();
        if (_a.seller == _msgSender()) revert bidderIsSeller();

        address payable _bidder = payable(_msgSender());

        if (_msgSender() == _a.highestBidder)
            revert ErrorMessage("Already highest bidder!");

        if (_a.highestBidder != address(0)) {
            if (
                !_sendPaymentToTokenEscrow(                    
                    _a.ERC20Contract,
                    _a.highestBid
                )
            ) revert funsNotTransfered();

            pendingFunds[_a.ERC20Contract][_a.highestBidder] += _a.highestBid;
        }

        bool success = IERC20(_a.ERC20Contract).transferFrom(
            _msgSender(),
            address(this),  
            bidAmount
        );

        if (!success) revert funsNotTransfered();

        _a.highestBid = bidAmount;
        _a.highestBidder = _bidder;

        emit HighestBidIncrease(_a.auctionId, _a.highestBidder, _a.highestBid);
    }

    /// @notice Method used to fetch all current live timed auctions on the Auctions.
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

    /// @notice For users who lost an auction.This will allow them to withdraw their pending token returns from the tokenEscrow.
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

    /// @notice For users who lost an auction.This will allow them to withdraw their pending returns from the TokenEscrow.
    /// @dev This method will withdraw the user funds from the escrow contract.
    /// @return success if transaction is completed succewssfully.
    function withdrawPendingFunds(
        bytes32 auctionId
    ) external returns (bool success) {
        MarketAuction memory currentAuction = auctionsMapping[auctionId];
        if (pendingFunds[currentAuction.ERC20Contract][_msgSender()] == 0)
            revert ErrorMessage("No pending Returns!");

        uint256 _amount = pendingFunds[currentAuction.ERC20Contract][
            _msgSender()
        ];

        if (_amount > 0) {            
            if (
                !withdrawPendingTokens(
                    payable(_msgSender()),
                    currentAuction.ERC20Contract
                )
            ) revert funsNotTransfered();
            pendingFunds[currentAuction.ERC20Contract][_msgSender()] = 0;
        }
        return true;
    }

    /// @notice Public method to finalise an auction.
    /// @param auctionId The auctionId to claim.
    /// @dev The winner of an auction is able to end the auction they won, by claiming the auction
    /// @return bool Returns true is auction has a highest bidder, returns false if the auction had no bids.
    function claimAuction(
        bytes32 auctionId
    ) public isLiveAuction(auctionId) returns (bool) {
        MarketAuction storage currentAuction = auctionsMapping[auctionId];

        if (block.timestamp < currentAuction.auctionEndTime)
            revert ErrorMessage("To soon!");
        if (currentAuction.ended) revert NotActive(currentAuction.auctionId);

        currentAuction.ended = true;
        isActiveTokenId[currentAuction.nftContract][
            currentAuction.itemId
        ] = false;

        if (currentAuction.highestBidder == address(0)) {
            _removeAuction(currentAuction.auctionId);
            emit NoBuyer(currentAuction.auctionId, currentAuction.itemId);
            return false;
        }

        _currentAuctionsSold += 1;

        bool success = IERC165(currentAuction.nftContract).supportsInterface(
            _INTERFACE_ID_ERC2981
        );

        if (!success) {
            if (currentAuction.isERC20) {
                if (_transferTokenFunds(auctionId) != true)
                    revert transferFunds();
            } else {
                if (_transferFunds(auctionId) != true) revert transferFunds();
            }
        } else {
            if (_transferRoyaltiesAndFunds(auctionId) != true)
                revert transferRoyaltiesFunds();
        }

        _sendAsset(auctionId, currentAuction.highestBidder);

        emit AuctionClaimed(
            currentAuction.auctionId,
            currentAuction.itemId,
            currentAuction.highestBidder,
            currentAuction.highestBid
        );

        _removeAuction(currentAuction.auctionId);

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
    function getAuctionId() public view returns (bytes32) {
        return bytes32(_currentAuctionId);
    }
}
