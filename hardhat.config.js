require("@openzeppelin/hardhat-upgrades");
require("hardhat-tracer");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("hardhat-log-remover");
require("hardhat-abi-exporter");
require("@nomicfoundation/hardhat-toolbox");
const bridgeConfig = require("./constants/bridgeConfig.json");

require("dotenv").config();
require("./tasks");

const fs = require("fs");

const {
  DEPLOYER_PRIVATE_KEY,
  PROD_DEPLOYER_PRIVATE_KEY,
  ETH_NODE,
  OPTIMISM_NODE,
  BASE_NODE,
  ARBITRUM_NODE,
} = process.env;

task("fork_reset", "Reset to local fork", async (taskArgs) => {
  await network.provider.request({
    method: "hardhat_reset",
    params: [],
  });
});

module.exports = {
  mocha: {
    timeout: 100000000,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.19",
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
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    hardhat: {
      // chainId: 1,
      // forking: {
      //   url: ARBITRUM_NODE || "",
      // },
    },
    mainnet: {
      url: ETH_NODE,
      chainId: 1,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
    arbgoerli: {
      url: `https://goerli-rollup.arbitrum.io/rpc`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
    },
    optimismgoerli: {
      url: OPTIMISM_NODE,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
      gasPrice: 10_000_000_000,
    },
    sepolia: {
      url: `https://rpc.ankr.com/eth_sepolia`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
    },
    optimism: {
      url: `https://rpc.ankr.com/optimism`,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
    bsctestnet: {
      url: `https://rpc.ankr.com/bsc_testnet_chapel`,
      chainId: 97,
      accounts: [`${DEPLOYER_PRIVATE_KEY}`],
    },
    polygonmumbai: {
      url: `https://rpc.ankr.com/polygon_mumbai`,
      accounts: [`${DEPLOYER_PRIVATE_KEY}`],
    },
    bsc_mainnet: {
      url: `https://bsc-dataseed.binance.org/`,
      chainId: 56,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
    },
    fujiavax: {
      url: `https://rpc.ankr.com/avalanche_fuji`,
      chainId: 43113,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
    },
    goerli: {
      url: `https://rpc.ankr.com/eth_goerli`,
      accounts: [`0x${DEPLOYER_PRIVATE_KEY}`],
      gasPrice: 100_000_000_000,
    },
    avalanche: {
      url: `https://api.avax.network/ext/bc/C/rpc`,
      chainId: 43114,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
    polygon: {
      url: `https://rpc.ankr.com/polygon`,
      chainId: 137,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
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
    kava: {
      url: "https://evm.kava.io/",
      chainId: 2222,
      accounts: [`0x${PROD_DEPLOYER_PRIVATE_KEY}`],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY,
      sepolia: process.env.ETHERSCAN_API_KEY,
      arbitrumOne: process.env.ARBISCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY,
      polygon: process.env.POLYGONSCAN_API_KEY,
      arbitrumGoerli: process.env.ARBISCAN_API_KEY,
      optimisticGoerli: process.env.OPTIMISM_API_KEY,
      optimisticEthereum: process.env.OPTIMISM_API_KEY,
      goerli: process.env.ETHERSCAN_API_KEY,
      base: process.env.BASESCAN_API_KEY,
      avalancheFujiTestnet: process.env.SNOWTRACE_API_KEY,
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
    enable: true,
    currency: "USD",
  },
  spdxLicenseIdentifier: {
    overwrite: false,
    runOnCompile: true,
  },
  abiExporter: {
    path: "./abi",
    runOnCompile: true,
    clear: true,
    flat: true,
    spacing: 2,
    format: "minimal",
    only: [":Vault$", ":BaseStrategy$", ":SgBridge$"],
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
  },
};

function getSortedFiles(dependenciesGraph) {
  const tsort = require("tsort");
  const graph = tsort();

  const filesMap = {};
  const resolvedFiles = dependenciesGraph.getResolvedFiles();
  resolvedFiles.forEach((f) => (filesMap[f.sourceName] = f));

  for (const [from, deps] of dependenciesGraph.entries()) {
    for (const to of deps) {
      graph.add(to.sourceName, from.sourceName);
    }
  }

  const topologicalSortedNames = graph.sort();

  const withEntries = topologicalSortedNames.concat(
    resolvedFiles.map((f) => f.sourceName)
  );

  const sortedNames = [...new Set(withEntries)];
  return sortedNames.map((n) => filesMap[n]);
}

function getFileWithoutImports(resolvedFile) {
  const IMPORT_SOLIDITY_REGEX = /^\s*import(\s+)[\s\S]*?;\s*$/gm;

  return resolvedFile.content.rawContent
    .replace(IMPORT_SOLIDITY_REGEX, "")
    .trim();
}

subtask(
  "flat:get-flattened-sources",
  "Returns all contracts and their dependencies flattened"
)
  .addOptionalParam("files", undefined, undefined, types.any)
  .addOptionalParam("output", undefined, undefined, types.string)
  .setAction(async ({ files, output }, { run }) => {
    const dependencyGraph = await run("flat:get-dependency-graph", {
      files,
    });

    let flattened = "";

    if (dependencyGraph.getResolvedFiles().length === 0) {
      return flattened;
    }

    const sortedFiles = getSortedFiles(dependencyGraph);

    let isFirst = true;
    for (const file of sortedFiles) {
      if (!isFirst) {
        flattened += "\n";
      }
      flattened += `// File ${file.getVersionedName()}\n`;
      flattened += `${getFileWithoutImports(file)}\n`;

      isFirst = false;
    }

    // Remove every line started with "pragma experimental ABIEncoderV2;" except the first one
    flattened = flattened.replace(
      /pragma experimental ABIEncoderV2;\n/gm,
      (
        (i) => (m) =>
          !i++ ? m : ""
      )(0)
    );
    flattened = flattened.replace(
      /pragma abicoder v2;\n/gm,
      (
        (i) => (m) =>
          !i++ ? m : ""
      )(0)
    );
    flattened = flattened.replace(
      /pragma solidity .*$\n/gm,
      (
        (i) => (m) =>
          !i++ ? m : ""
      )(0)
    );

    flattened = flattened.trim();
    if (output) {
      console.log("Writing to", output);
      fs.writeFileSync(output, flattened);
      return "";
    }
    return flattened;
  });

subtask("flat:get-dependency-graph")
  .addOptionalParam("files", undefined, undefined, types.any)
  .setAction(async ({ files }, { run }) => {
    const sourcePaths =
      files === undefined
        ? await run("compile:solidity:get-source-paths")
        : files.map((f) => fs.realpathSync(f));

    const sourceNames = await run("compile:solidity:get-source-names", {
      sourcePaths,
    });

    const dependencyGraph = await run("compile:solidity:get-dependency-graph", {
      sourceNames,
    });

    return dependencyGraph;
  });

task("flat", "Flattens and prints contracts and their dependencies")
  .addOptionalVariadicPositionalParam(
    "files",
    "The files to flatten",
    undefined,
    types.inputFile
  )
  .addOptionalParam(
    "output",
    "Specify the output file",
    undefined,
    types.string
  )
  .setAction(async ({ files, output }, { run }) => {
    console.log(
      await run("flat:get-flattened-sources", {
        files,
        output,
      })
    );
  });

subtask("compile:solidity:transform-import-name").setAction(
  async ({ importName }, _hre, runSuper) => {
    const remappings = { "@yearn-protocol/": "lib/yearn-vaults/" };
    for (const [from, to] of Object.entries(remappings)) {
      if (importName.startsWith(from) && !importName.startsWith(".")) {
        return importName.replace(from, to);
      }
    }
    return importName;
  }
);

subtask("compile:solidity:get-compilation-job-for-file").setAction(
  async ({ dependencyGraph, file }, _hre, runSuper) => {
    const job = await runSuper({ dependencyGraph, file });
    if ("reason" in job) return job;
    const remappings = { "@yearn-protocol/": "lib/yearn-vaults/" };
    job.getSolcConfig().settings.remappings = Object.entries(remappings).map(
      ([from, to]) => `${from}=${to}`
    );
    return job;
  }
);

task("sign", "Sign harvest")
  .addPositionalParam("addr")
  .setAction(async (taskArgs) => {
    const [signer] = await ethers.getSigners();
    const networkName = hre.network.name;
    const strategy = await ethers.getContractAt(
        "BaseStrategy",
        taskArgs.addr
    );

    console.log(`Signing by ${signer.address}`);

    const signPayload = await strategy.strategistSignMessageHash();
    console.log(`Sign payload ${signPayload}`);
    const signature = await signer.signMessage(
        ethers.utils.arrayify(signPayload)
    );

    console.log("Signature", signature);
  });

  task("harvestInfo", "Info harvest")
  .addPositionalParam("chain")
  .addPositionalParam("addr")
  .setAction(async (taskArgs) => {
    const [signer] = await ethers.getSigners();
    const networkName = hre.network.name;

    const vault = await ethers.getContractAt(
        "Vault",
        bridgeConfig[networkName].vault
    );

    
    const strategyInfo = await vault.strategies(
        taskArgs.chain,
        taskArgs.addr
    );
    const debtOutstanding = await vault.debtOutstanding(
      taskArgs.chain,
      taskArgs.addr
    );
    const creditAvailable = await vault.creditAvailable(
      taskArgs.chain,
      taskArgs.addr
    );

    console.log(`Total debt=${(strategyInfo.totalDebt)}`);
    console.log(`Debt outstanding=${(debtOutstanding)}`);
    console.log(`Credit available=${(creditAvailable)}`);
    console.log(`Debt ratio=${(strategyInfo.debtRatio)}`);
  });