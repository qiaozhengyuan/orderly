const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Pool Contract", function () {
  let Pool;
  let pool;
  let owner;
  let tokenA;
  let tokenB;

  beforeEach(async function () {
    // Get the contract factories for ERC20 tokens and the Pool contract
    const Token = await ethers.getContractFactory("ERC20Mock");
    Pool = await ethers.getContractFactory("Pool");

    // Deploy two mock ERC20 tokens (Token A and Token B)
    tokenA = await Token.deploy("Token A", "TKA", 1000000);
    tokenB = await Token.deploy("Token B", "TKB", 1000000);

    // Get signers (accounts) from the hardhat environment
    [owner] = await ethers.getSigners();

    // Deploy the Pool contract
    pool = await upgrades.deployProxy(Pool, [[await tokenA.getAddress(), await tokenB.getAddress()]], {
      initializer: "initialize",
    });

    await pool.waitForDeployment();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), owner.address)).to.be
        .true;
    });

    it("Should initialize with the correct tokens", async function () {
      const tokens = await pool.tokens(0);
      expect(tokens).to.equal(await tokenA.getAddress());
    });
  });

  describe("Liquidity", function () {
    it("Should allow adding liquidity", async function () {
      // Approve Pool contract to spend owner's tokens
      await tokenA.connect(owner).approve(await pool.getAddress(), 1000);
      await tokenB.connect(owner).approve(await pool.getAddress(), 1000);

      // Add liquidity to the pool
      await pool.connect(owner).addLiquidity([1000, 1000]);

      // Check liquidity balance of owner
      const liquidityBalance = await pool.liquidityBalance(owner.address);
      expect(liquidityBalance).to.be.gt(0);
    });

    it("Should allow removing liquidity", async function () {
      // Approve and add liquidity first
      await tokenA.connect(owner).approve(await pool.getAddress(), 1000);
      await tokenB.connect(owner).approve(await pool.getAddress(), 1000);
      await pool.connect(owner).addLiquidity([1000, 1000]);

      const liquidityBalanceBefore = await pool.liquidityBalance(owner.address);

      // Remove liquidity
      await pool.connect(owner).removeLiquidity(500);

      // Check remaining liquidity balance
      const liquidityBalance = await pool.liquidityBalance(owner.address);
      expect(liquidityBalance).to.equal(liquidityBalanceBefore - 500n);
    });
  });

  describe("Swaps", function () {
    it("Should allow swapping between tokens", async function () {
      // Approve and add liquidity first
      await tokenA.connect(owner).approve(await pool.getAddress(), 1000);
      await tokenB.connect(owner).approve(await pool.getAddress(), 1000);
      await pool.connect(owner).addLiquidity([1000, 1000]);

      // Approve tokenA to be swapped
      await tokenA.connect(owner).approve(await pool.getAddress(), 500);

      const tokenBBalanceBefore = await tokenB.balanceOf(owner.address);

      // Perform a swap (Token A -> Token B)
      await pool.connect(owner).swap(0, 1, 500, 1); // tokenA -> tokenB

      // Check the final balance of Token B
      const tokenBBalance = await tokenB.balanceOf(owner.address);
      expect(tokenBBalance).to.be.gt(tokenBBalanceBefore);
    });
  });
});
