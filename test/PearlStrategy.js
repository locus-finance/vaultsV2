const {
    loadFixture,
    mine,
    reset,
} = require("@nomicfoundation/hardhat-network-helpers");
const { expect } = require("chai");
const { utils } = require("ethers");
const { ethers, upgrades } = require("hardhat");

const networksConfig = require("../constants/networks.json");
const { getEnv } = require("../utils");

const IERC20_SOURCE = "@openzeppelin/contracts/token/ERC20/IERC20.sol:IERC20";

const POLYGON_NODE_URL = getEnv("POLYGON_NODE");
const POLYGON_FORK_BLOCK = getEnv("POLYGON_FORK_BLOCK");
const TARGET_NETWORK = "polygon";
const ADDRESS_ONE = "0x0000000000000000000000000000000000000001";

describe("PearlStrategy", function () {
    const TOKENS = {
        USDC: {
            address: "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174",
            whale: "0x9c2bd617b77961ee2c5e3038dfb0c822cb75d82a",
            decimals: 6,
        },
        PEARL: {
            address: "0x7238390d5f6f64e67c3211c343a410e2a3dec142",
            whale: "0xaebb8fdbd5e52f99630cebb80d0a1c19892eb4c2",
            decimals: 18,
        },
        ETH: {
            whale: "0x06959153b974d0d5fdfd87d561db6d8d4fa0bb0b",
        },
    };

    async function deployContractAndSetVariables() {
        await reset(POLYGON_NODE_URL, Number(POLYGON_FORK_BLOCK));

        const [deployer, whale] = await ethers.getSigners();

        const PearlStrategy = await ethers.getContractFactory(
            "MockPearlStrategy"
        );
        const pearlStrategy = await upgrades.deployProxy(
            PearlStrategy,
            [
                networksConfig[TARGET_NETWORK].lzEndpoint,
                deployer.address,
                TOKENS.USDC.address,
                ADDRESS_ONE,
                0,
                0,
                ADDRESS_ONE,
                networksConfig[TARGET_NETWORK].sgRouter,
            ],
            {
                initializer: "initialize",
                kind: "transparent",
            }
        );
        await pearlStrategy.deployed();

        const want = await ethers.getContractAt(
            IERC20_SOURCE,
            TOKENS.USDC.address
        );

        return {
            strategy: pearlStrategy,
            deployer,
            whale,
            want,
        };
    }

    async function dealTokensToAddress(
        address,
        dealToken,
        amountUnscaled = "100"
    ) {
        const token = await ethers.getContractAt(
            IERC20_SOURCE,
            dealToken.address
        );

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [dealToken.whale],
        });
        const tokenWhale = await ethers.getSigner(dealToken.whale);

        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [TOKENS.ETH.whale],
        });
        const ethWhale = await ethers.getSigner(TOKENS.ETH.whale);

        await ethWhale.sendTransaction({
            to: tokenWhale.address,
            value: utils.parseEther("50"),
        });

        await token
            .connect(tokenWhale)
            .transfer(
                address,
                utils.parseUnits(amountUnscaled, dealToken.decimals)
            );
    }

    it("should deploy strategy", async function () {
        const { strategy } = await loadFixture(deployContractAndSetVariables);
        expect(await strategy.name()).to.equal("PearlStrategy");
    });

    it("should report reasonable prices", async function () {
        const { strategy } = await loadFixture(deployContractAndSetVariables);
        expect(
            Number(await strategy.pearlToWant(utils.parseEther("1")))
        ).to.be.greaterThan(0);
        expect(
            Number(await strategy.daiToWant(utils.parseEther("1")))
        ).to.be.greaterThan(0);
        expect(
            Number(await strategy.usdrToWant(utils.parseEther("1")))
        ).to.be.greaterThan(0);
        expect(
            Number(await strategy.usdrLpToWant(utils.parseEther("1")))
        ).to.be.greaterThan(0);
        expect(
            Number(await strategy.wantToUsdrLp(utils.parseEther("1")))
        ).to.be.greaterThan(0);
    });

    it("should harvest free funds", async function () {
        const { strategy } = await loadFixture(deployContractAndSetVariables);

        await dealTokensToAddress(strategy.address, TOKENS.USDC, "1000");
        expect(await strategy.estimatedTotalAssets()).to.equal(
            ethers.utils.parseUnits("1000", 6)
        );

        await strategy.adjustPosition(0);

        expect(await strategy.estimatedTotalAssets()).to.be.closeTo(
            ethers.utils.parseUnits("1000", 6),
            ethers.utils.parseUnits("100", 6)
        );
        expect(Number(await strategy.balanceOfLpStaked())).to.be.greaterThan(0);
    });

    it("should sell PEARL", async function () {
        const { strategy } = await loadFixture(deployContractAndSetVariables);

        await dealTokensToAddress(strategy.address, TOKENS.PEARL, "1000");
        const token = await ethers.getContractAt(
            IERC20_SOURCE,
            TOKENS.PEARL.address
        );
        expect(await token.balanceOf(strategy.address)).to.equal(
            utils.parseEther("1000")
        );

        await strategy.sellPearl(utils.parseEther("1000"));
        expect(Number(await strategy.estimatedTotalAssets())).to.be.greaterThan(
            0
        );
    });

    it("should withdraw funds after harvest", async function () {
        const { strategy, want } = await loadFixture(
            deployContractAndSetVariables
        );

        await dealTokensToAddress(strategy.address, TOKENS.USDC, "1000");
        await strategy.adjustPosition(0);

        await mine(300, { interval: 20 });

        const balanceBefore = await want.balanceOf(strategy.address);
        expect(Number(balanceBefore)).to.be.closeTo(
            ethers.utils.parseUnits("0", 6),
            ethers.utils.parseUnits("50", 6)
        );

        await strategy.withdrawSome(ethers.utils.parseUnits("100", 6));

        expect(
            Number(await want.balanceOf(strategy.address))
        ).to.be.greaterThan(Number(balanceBefore));
    });

    it("should liquidate position", async function () {
        const { strategy, want } = await loadFixture(
            deployContractAndSetVariables
        );

        await dealTokensToAddress(strategy.address, TOKENS.USDC, "1000");
        await strategy.adjustPosition(0);

        await mine(300, { interval: 20 });

        const balanceBefore = await want.balanceOf(strategy.address);
        expect(Number(balanceBefore)).to.be.closeTo(
            ethers.utils.parseUnits("0", 6),
            ethers.utils.parseUnits("50", 6)
        );

        await strategy.liquidatePosition(ethers.utils.parseUnits("100", 6));
    });
});
