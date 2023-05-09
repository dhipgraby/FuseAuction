const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FuseAuction", function () {
    let FuseAuction, fuseAuction, NFTMock, nftMock, ERC20Mock, erc20Mock, owner, addr1, addr2;

    const AUCTION_TIME = 450 // 7.5 minutes

    beforeEach(async function () {
        // Deploy NFT Mock contract
        NFTMock = await ethers.getContractFactory("NFTMock");
        nftMock = await NFTMock.deploy();
        await nftMock.deployed();

        // // Deploy ERC20 Mock contract
        ERC20Mock = await ethers.getContractFactory("GLDToken");
        erc20Mock = await ERC20Mock.deploy();
        await erc20Mock.deployed()
        // // Deploy FuseAuction contract
        FuseAuction = await ethers.getContractFactory("FuseAuction");
        fuseAuction = await FuseAuction.deploy();
        await fuseAuction.deployed();

        // Set up addresses
        [owner, addr1, addr2] = await ethers.getSigners();
    });

    // describe("Auction creation", function () {

    //     it("Should create a native token auction", async function () {

    //         await nftMock.connect(owner).safeMint(owner.address);
    //         await nftMock.connect(owner).approve(fuseAuction.address, 1);

    //         const tx = await fuseAuction.connect(owner).createNativeAuction(1, AUCTION_TIME, ethers.utils.parseEther("0.1"), nftMock.address);
    //         await tx.wait();

    //         const auctionId = await fuseAuction.getAuctionId();            
    //         const auction = await fuseAuction.auctionsMapping(auctionId);            
    //         expect(auction.itemId).to.equal(1);
    //     });

    //     it("Should create an ERC20 token auction", async function () {
    //         await nftMock.connect(owner).mint(owner.address,2);
    //         await nftMock.connect(owner).approve(fuseAuction.address, 2);

    //         const tx = await fuseAuction.connect(owner).createERC20Auction(2, AUCTION_TIME, 100, nftMock.address, erc20Mock.address);
    //         await tx.wait();

    //         const auctionId = await fuseAuction.getAuctionId();            
    //         const auction = await fuseAuction.auctionsMapping(auctionId);

    //         expect(auction.itemId).to.equal(2);
    //     });
    // });

    // describe("Bidding on auctions", function () {
    //     beforeEach(async function () {
    //         await nftMock.connect(owner).mint(owner.address, 3);
    //         await nftMock.connect(owner).approve(fuseAuction.address, 3);

    //         await erc20Mock.connect(owner).transfer(addr1.address, 200);
    //         await erc20Mock.connect(addr1).approve(fuseAuction.address, 200);
    //     });

    //     it("Should place a bid on a native token auction", async function () {
    //         await fuseAuction.connect(owner).createNativeAuction(3, AUCTION_TIME, ethers.utils.parseEther("0.1"), nftMock.address);
    //         const bidAmount = ethers.utils.parseEther("0.2");
    //         const auctionId = await fuseAuction.getAuctionId(); 
    //         await fuseAuction.connect(addr1).bid(auctionId, { value: bidAmount });

    //         const auction = await fuseAuction.auctionsMapping(auctionId);
    //         expect(auction.highestBid).to.equal(bidAmount);
    //     });
    //     it("Should place a bid on an ERC20 token auction", async function () {                        
    //         const minBid = 100;
    //         const bidAmount = 200;
    //         await fuseAuction.connect(owner).createERC20Auction(3, AUCTION_TIME, minBid, nftMock.address,erc20Mock.address);
    //         const auctionId = await fuseAuction.getAuctionId(); 
    //         await fuseAuction.connect(addr1).bidERC20(auctionId, bidAmount);

    //         const auction = await fuseAuction.auctionsMapping(auctionId);
    //         expect(auction.highestBid).to.equal(bidAmount);
    //     });
    // });

    // describe("Claiming auctions", function () {
    //     beforeEach(async function () {
    //         await nftMock.connect(owner).mint(owner.address, 4);
    //         await nftMock.connect(owner).approve(fuseAuction.address, 4);
    //         await erc20Mock.connect(owner).transfer(addr1.address, 200);
    //         await erc20Mock.connect(addr1).approve(fuseAuction.address, 200);
    //     });

    // it("Should claim a native token auction", async function () {        
    //     await fuseAuction.connect(owner).createNativeAuction(4, 1, ethers.utils.parseEther("0.1"), nftMock.address);
    //     const initialOwnerBalance = await ethers.provider.getBalance(owner.address);
    //     const bidAmount = ethers.utils.parseEther("0.2");
    //     const auctionId = await fuseAuction.getAuctionId();

    //     await fuseAuction.connect(addr1).bid(auctionId, { value: bidAmount });
    //     await new Promise((resolve) => setTimeout(resolve, 2000));

    //     const tx = await fuseAuction.connect(addr1).claimAuction(auctionId);
    //     const txReceipt = await tx.wait();
    //     const gasUsed = txReceipt.gasUsed;
    //     const gasPrice = tx.gasPrice;
    //     const gasCost = gasUsed.mul(gasPrice);

    //     const updatedOwnerBalance = await ethers.provider.getBalance(owner.address);
    //     const expectedUpdatedOwnerBalance = initialOwnerBalance.add(bidAmount).sub(gasCost);            

    //     console.log(updatedOwnerBalance,expectedUpdatedOwnerBalance);

    //     const auction = await fuseAuction.auctionsMapping(auctionId);
    //     //Check if the owner's balance has increased by the winning bid amount
    //     // expect(updatedOwnerBalance).to.equal(expectedUpdatedOwnerBalance);
    //     expect(auction.ended).to.equal(true);
    //     expect(await nftMock.ownerOf(4)).to.equal(addr1.address);
    // });

    // it("Should claim an ERC20 token auction", async function () {

    //     const initialOwnerBalance = await erc20Mock.balanceOf(owner.address);
    //     await fuseAuction.connect(owner).createERC20Auction(4, 1, 100, nftMock.address, erc20Mock.address);

    //     const bidAmount = 200;
    //     const auctionId = await fuseAuction.getAuctionId();
    //     await fuseAuction.connect(addr1).bidERC20(auctionId, bidAmount);

    //     await new Promise((resolve) => setTimeout(resolve, 2000));

    //     const updatedOwnerBalance = await erc20Mock.balanceOf(owner.address);
    //     const auction = await fuseAuction.auctionsMapping(auctionId);
    //     //Check if the owner's balance has increased by the winning bid amount
    //     expect(updatedOwnerBalance).to.equal(initialOwnerBalance.add(bidAmount));
    //     expect(auction.ended).to.equal(true);
    //     expect(await nftMock.ownerOf(4)).to.equal(addr1.address);
    // });
    // });

    describe("Withdrawing pending returns and funds", function () {
        beforeEach(async function () {
            await nftMock.connect(owner).mint(owner.address, 5);
            await nftMock.connect(owner).approve(fuseAuction.address, 5);
            await erc20Mock.connect(owner).transfer(addr1.address, 200);
            await erc20Mock.connect(addr1).approve(fuseAuction.address, 200);
            await erc20Mock.connect(owner).transfer(addr2.address, 300);
            await erc20Mock.connect(addr2).approve(fuseAuction.address, 300);
        });

        // it("Should withdraw pending native token returns", async function () {

        //     await fuseAuction.connect(owner).createNativeAuction(5, 1, ethers.utils.parseEther("0.1"), nftMock.address);
        //     const auctionId = await fuseAuction.getAuctionId();
        //     const addr1Bid = ethers.utils.parseEther("0.2") 
        //     await fuseAuction.connect(addr1).bid(auctionId, { value: addr1Bid });
        //     await fuseAuction.connect(addr2).bid(auctionId, { value: ethers.utils.parseEther("0.3") });

        //     await new Promise((resolve) => setTimeout(resolve, 2000));

        //     //Address2 CLAIMS AUCTION
        //     await fuseAuction.connect(addr2).claimAuction(auctionId);

        //     const addr1Balance = await ethers.provider.getBalance(addr1.address);

        //     //Address1 WITHDRAW PENDING FUNDS
        //     const withdrawTx = await fuseAuction.connect(addr1).withdrawPendingReturns();
        //     const wReceipt = await withdrawTx.wait();
        //     const wgasUsed = wReceipt.gasUsed;
        //     const wgasPrice = withdrawTx.gasPrice;
        //     const wgasCost = wgasUsed.mul(wgasPrice);

        //     const addr1UpdatedBalance = (await ethers.provider.getBalance(addr1.address)).add(wgasCost);

        //     expect(addr1UpdatedBalance.sub(addr1Balance)).to.equal(addr1Bid);
        // });

        it("Should withdraw pending ERC20 token funds", async function () {

            await fuseAuction.connect(owner).createERC20Auction(5, 1, 100, nftMock.address, erc20Mock.address);
            const auctionId = await fuseAuction.getAuctionId();

            const addr1_beforeWithdraw = await erc20Mock.balanceOf(addr1.address);

            await fuseAuction.connect(addr1).bidERC20(auctionId, 200);
            await fuseAuction.connect(addr2).bidERC20(auctionId, 300);

            //Address2 CLAIMS AUCTION
            await fuseAuction.connect(addr2).claimAuction(auctionId);

            //ADDR1 WITHDRAW PENDING TOKEN FUNDS
            await fuseAuction.connect(addr1).withdrawPendingFunds(auctionId);

            // const addr1_afterWithdraw = await erc20Mock.balanceOf(addr1.address);

            // expect(addr1_beforeWithdraw).to.equal(addr1_afterWithdraw);
        });
    });
});
