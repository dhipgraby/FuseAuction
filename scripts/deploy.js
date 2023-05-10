const hre = require("hardhat");

async function main() {
	const NFT_Contract = await hre.ethers.getContractFactory("NFTMock");
	const ERC20_Contract = await hre.ethers.getContractFactory("GLDToken");
	const AUCTION_Contract = await hre.ethers.getContractFactory("FuseAuction");

	const nftContract = await NFT_Contract.deploy();
	const ercContract = await ERC20_Contract.deploy();
	const auctionContract = await AUCTION_Contract.deploy();

	console.log("NFTMock deployed to:", nftContract.address);
	console.log("ERC20 deployed to:", ercContract.address);
	console.log("Auction deployed to:", auctionContract.address);
}

main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});