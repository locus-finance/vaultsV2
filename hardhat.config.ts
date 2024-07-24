import bridgeConfig from "./constants/bridgeConfig.json";
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-verify";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import "hardhat-tracer";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-ethers";

require("dotenv").config();
require("./tasks");

const {
  DEPLOYER_PRIVATE_KEY,
  PROD_DEPLOYER_PRIVATE_KEY,
  ETH_NODE,
  BASE_NODE,
  ARBITRUM_NODE,
} = process.env;

const config: HardhatUserConfig = {
  mocha: {
    timeout: 100000000,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.24",
        settings: {
          viaIR: true,
          optimizer: {
            enabled: true,
            runs: 10,
          },
          outputSelection: {
            "*": {
              "*": ["storageLayout"],
            },
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 42161,
      forking: {
        url: ARBITRUM_NODE || "",
      },
      allowUnlimitedContractSize: true
    },
    mainnet: {
      url: ETH_NODE || "",
      chainId: 1,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
    bsc_mainnet: {
      url: `https://bsc-dataseed.binance.org/`,
      chainId: 56,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
    },
    arbitrumOne: {
      url: `https://arb1.arbitrum.io/rpc`,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
    base: {
      url: BASE_NODE || "",
      chainId: 8453,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      base: process.env.BASESCAN_API_KEY || "",
      kava: "api key is not required by the Kava explorer, but can't be empty",
    },
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
      {
        network: "kava",
        chainId: 2222,
        urls: {
          apiURL: "https://kavascan.com/api",
          browserURL: "https://kavascan.com",
        },
      },
    ],
  },
  gasReporter: {
    currency: "USD",
  },
  contractSizer: {
    runOnCompile: true,
  },
};

export default config;
