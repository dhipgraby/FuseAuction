# FuseAuction 🚀
FuseAuction is a decentralized auction platform built on Ethereum that allows users to create auctions for NFTs and bid using either native Ether or ERC20 tokens. The contract interacts with both NFT and ERC20 contracts to ensure seamless auction creation and bidding.

## Table of Contents
- Features
- Installation
- Running Tests
- Usage
- Functions
- Events
- License

## Features ✨

- Supports NFT and ERC20 contracts
- Create auctions using either Ether or ERC20 tokens
- Bid on auctions using either Ether or ERC20 tokens
- Withdraw pending returns for losing bidders
- Claim auctions and transfer assets for auction winners

## Installation 📦
Clone the repository:
bash

<pre>
git clone https://github.com/yourusername/FuseAuction.git
Change into the directory and install dependencies:
bash
</pre>

<pre>
cd FuseAuction
npm install
Run the Hardhat local Ethereum node:
bash
</pre>

<pre>
npx hardhat node
Compile the contracts:
bash
</pre>

<pre>
npx hardhat compile
Deploy the contracts:
bash
</pre>

<pre>
npx hardhat run scripts/deploy.js --network localhost
Running Tests 🧪
Run the tests using Hardhat:
</pre>

<pre>
npx hardhat test
</pre>

## Usage 📚
** Creating an auction **
To create an auction, call the createNativeAuction or createERC20Auction function, passing in the following parameters:

itemId: The ID of the NFT you want to auction
biddingTime: The duration of the auction in seconds
minimumBid: The starting price of the auction
nftContract: The address of the NFT contract
For createERC20Auction, also provide:

tokenAddress: The address of the ERC20 token used for bidding
Bidding on an auction
To bid on an auction, call the bid or bidERC20 function, passing in the following parameters:

auctionId: The ID of the auction you want to bid on
For bidERC20, also provide:

bidAmount: The amount of ERC20 tokens you want to bid
Withdrawing pending returns
To withdraw pending returns, call the withdrawPendingReturns or withdrawPendingFunds function.

For withdrawPendingFunds, also provide:

auctionId: The ID of the auction you want to withdraw funds from
Claiming an auction
To claim an auction, call the claimAuction function, passing in the following parameters:

auctionId: The ID of the auction you want to claim
## Functions 📝
- createNativeAuction
- createERC20Auction
- bid
- bidERC20
- fetchMarketAuctions
- withdrawPendingReturns
- withdrawPendingFunds
- claimAuction
- getAuctionId
- checkPendingFunds

## Events 📣
- MarketAuctionCreated
- HighestBidIncrease
- WithdrawPendingReturns
- AuctionClaimed
- AuctionRemoved
