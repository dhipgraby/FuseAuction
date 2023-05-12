require('@nomicfoundation/hardhat-toolbox');
require("@nomiclabs/hardhat-ethers");
require('dotenv').config()
const path = require("path");

module.exports = {
  // paths: {
  //   sources: "./contracts",
  //   artifacts: "./artifacts",
  // },
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  allowUnlimitedContractSize: true,
  networks: {
    ganache: {
      url: 'http://127.0.0.1:8545',
      gasPrice: "auto",
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
      },
      accountsBalance: "10000000000000000000000",
    },
    hardhat: {
      gasPrice: "auto",
      accounts: {
        mnemonic:
          "test test test test test test test test test test test junk",
        accountsBalance: "10000000000000000000000",
      },
    },
    fuse: {
      accounts: [`${process.env.DEPLOYER_PRIVKEY}`],
      url: `https://rpc.fusespark.io`,
    },
    /* ETH_MAINNET: {
      accounts: [`${process.env.PRIVATE_KEY}`],
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
    },
    ETH_GOERLI: {
      accounts: [`${process.env.PRIVATE_KEY}`],
      url: `https://eth-goerli.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
    }, */
  },
  etherscan: {
    apiKey: `${process.env.ETHERSCAN_API_KEY}`,
  },
};
