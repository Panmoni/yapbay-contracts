const { ethers } = require("hardhat");

async function main() {
  // Get the contract factory
  const Account = await ethers.getContractFactory("Account");

  // Deploy the contract
  const account = await Account.deploy();

  // Wait for the contract to be deployed
  await account.deployed();

  console.log("Account contract deployed to:", account.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
