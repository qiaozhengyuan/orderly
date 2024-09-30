const { ethers, upgrades } = require("hardhat");

const tokens = [
    ethers.ZeroAddress,
    "0x0B925eD163218f6662a35e0f0371Ac234f9E9371",
    "0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84"
]

async function main() {
    // Get the contract factory for the Pool contract
    const Pool = await ethers.getContractFactory("Pool");

    console.log("Deploying the Pool contract...");

    // Deploy the contract using OpenZeppelin upgradeable proxy
    const pool = await upgrades.deployProxy(Pool, [tokens], { initializer: 'initialize' });

    await pool.deployed();

    console.log(`Pool deployed to: ${pool.address}`);
}

// Catch any errors
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
