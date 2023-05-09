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

    describe("Auction creation", function () {
        
        it("Should create a native token auction", async function () {

            await nftMock.connect(owner).safeMint(owner.address);
            await nftMock.connect(owner).approve(fuseAuction.address, 1);

            const tx = await fuseAuction.connect(owner).createNativeAuction(1, AUCTION_TIME, ethers.utils.parseEther("0.1"), nftMock.address);
            await tx.wait();

            const auctionId = await fuseAuction.getAuctionId();            
            const auction = await fuseAuction.auctionsMapping(auctionId);            
            expect(auction.itemId).to.equal(1);
        });

        it("Should create an ERC20 token auction", async function () {
            await nftMock.connect(owner).mint(owner.address,2);
            await nftMock.connect(owner).approve(fuseAuction.address, 2);

            const tx = await fuseAuction.connect(owner).createERC20Auction(2, AUCTION_TIME, 100, nftMock.address, erc20Mock.address);
            await tx.wait();

            const auctionId = await fuseAuction.getAuctionId();            
            const auction = await fuseAuction.auctionsMapping(auctionId);

            expect(auction.itemId).to.equal(2);
        });
    });

    describe("Bidding on auctions", function () {
        beforeEach(async function () {
            await nftMock.connect(owner).mint(owner.address, 3);
            await nftMock.connect(owner).approve(fuseAuction.address, 3);
            
            await erc20Mock.connect(owner).transfer(addr1.address, 200);
            await erc20Mock.connect(addr1).approve(fuseAuction.address, 200);
        });

        it("Should place a bid on a native token auction", async function () {
            await fuseAuction.connect(owner).createNativeAuction(3, AUCTION_TIME, ethers.utils.parseEther("0.1"), nftMock.address);
            const bidAmount = ethers.utils.parseEther("0.2");
            const auctionId = await fuseAuction.getAuctionId(); 
            await fuseAuction.connect(addr1).bid(auctionId, { value: bidAmount });

            const auction = await fuseAuction.auctionsMapping(auctionId);
            expect(auction.highestBid).to.equal(bidAmount);
        });
        it("Should place a bid on an ERC20 token auction", async function () {                        
            const minBid = 100;
            const bidAmount = 200;
            await fuseAuction.connect(owner).createERC20Auction(3, AUCTION_TIME, minBid, nftMock.address,erc20Mock.address);
            const auctionId = await fuseAuction.getAuctionId(); 
            await fuseAuction.connect(addr1).bidERC20(auctionId, bidAmount);

            const auction = await fuseAuction.auctionsMapping(auctionId);
            expect(auction.highestBid).to.equal(bidAmount);
        });
    });
});

describe("Claiming auctions", function () {
    beforeEach(async function () {
        await nftMock.connect(owner).mint(owner.address, 4);
        await nftMock.connect(owner).approve(fuseAuction.address, 4);
        await fuseAuction.connect(owner).createNativeAuction(4, 1, ethers.utils.parseEther("0.1"), nftMock.address);

        await erc20Mock.connect(owner).transfer(addr1.address, 200);
        await erc20Mock.connect(addr1).approve(fuseAuction.address, 200);
    });

    it("Should claim a native token auction", async function () {
        const bidAmount = ethers.utils.parseEther("0.2");
        const auctionId = await fuseAuction.getAuctionId(); 
        await fuseAuction.connect(addr1).bid(auctionId, { value: bidAmount });

        await new Promise((resolve) => setTimeout(resolve, 2000));

        await fuseAuction.connect(addr1).claimAuction(auctionId);

        const auction = await fuseAuction.auctionsMapping(auctionId);

        expect(auction.ended).to.equal(true);
        expect(await nftMock.ownerOf(4)).to.equal(addr1.address);
    });

//     it("Should claim an ERC20 token auction", async function () {
//         const bidAmount = 200;
//         const auctionId = await fuseAuction.getAuctionId(); 
//         await fuseAuction.connect(addr1).bidERC20(auctionId, bidAmount);

//         await new Promise((resolve) => setTimeout(resolve, 2000));

//         await fuseAuction.connect(addr1).claimAuction(auctionId);

//         const auction = await fuseAuction.auctionsMapping(auctionId);

//         expect(auction.ended).to.equal(true);
//         expect(await nftMock.ownerOf(4)).to.equal(addr1.address);
//     });
});

// describe("Withdrawing pending returns and funds", function () {
//     beforeEach(async function () {
//         await nftMock.connect(owner).mint(owner.address, 5);
//         await nftMock.connect(owner).approve(fuseAuction.address, 5);
//         await fuseAuction.connect(owner).createNativeAuction(5, 60 * 60, ethers.utils.parseEther("0.1"), nftMock.address);

//         await erc20Mock.connect(owner).transfer(addr1.address, 200);
//         await erc20Mock.connect(addr1).approve(fuseAuction.address, 200);

//         await fuseAuction.connect(addr1).bid(1, { value: ethers.utils.parseEther("0.2") });
//     });

//     it("Should withdraw pending native token returns", async function () {
//         const balanceBefore = await ethers.provider.getBalance(addr1.address);

//         await fuseAuction.connect(addr1).withdrawPendingReturns();

//         const balanceAfter = await ethers.provider.getBalance(addr1.address);

//         expect(balanceAfter.sub(balanceBefore)).to.equal(ethers.utils.parseEther("0.2"));
//     });

//     it("Should withdraw pending ERC20 token funds", async function () {
//         await fuseAuction.connect(addr1).bidERC20(1, 200);

//         const balanceBefore = await erc20Mock.balanceOf(addr1.address);

//         await fuseAuction.connect(addr1).withdrawPendingFunds(1);

//         const balanceAfter = await erc20Mock.balanceOf(addr1.address);

//         expect(balanceAfter.sub(balanceBefore)).to.equal(200);
//     });
// });