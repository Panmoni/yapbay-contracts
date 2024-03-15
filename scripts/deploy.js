const { ethers } = require("hardhat");

async function main() {
  // Get the contract factories
  const ContractRegistry = await ethers.getContractFactory("ContractRegistry");
  const Account = await ethers.getContractFactory("Account");
  const Offer = await ethers.getContractFactory("Offer");
  const Trade = await ethers.getContractFactory("Trade");
  const Escrow = await ethers.getContractFactory("Escrow");
  const Rating = await ethers.getContractFactory("Rating");
  const Reputation = await ethers.getContractFactory("Reputation");
  const Arbitration = await ethers.getContractFactory("Arbitration");

  // Get the deployer's address
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Set the platformFeePercentage and penaltyPercentage values
  const platformFeePercentage = 0; // 0% platform fee percentage
  const penaltyPercentage = 5; // 5% penalty percentage

  // Deploy the ContractRegistry contract
  const registry = await ContractRegistry.deploy(
    ethers.constants.AddressZero, // Placeholder for Account address
    ethers.constants.AddressZero, // Placeholder for Offer address
    ethers.constants.AddressZero, // Placeholder for Trade address
    ethers.constants.AddressZero, // Placeholder for Escrow address
    ethers.constants.AddressZero, // Placeholder for Rating address
    ethers.constants.AddressZero, // Placeholder for Reputation address
    ethers.constants.AddressZero // Placeholder for Arbitration address
  );
  await registry.deployed();
  console.log("ContractRegistry contract deployed to:", registry.address);

  // Deploy the Account contract
  const account = await Account.deploy(registry.address);
  await account.deployed();
  console.log("Account contract deployed to:", account.address);

  // Deploy the Escrow contract
  const escrow = await Escrow.deploy(
    deployer.address, // Set the owner address to the deployer's address
    registry.address,
    platformFeePercentage,
    penaltyPercentage
  );
  await escrow.deployed();
  console.log("Escrow contract deployed to:", escrow.address);

  // Deploy the Arbitration contract
  const arbitration = await Arbitration.deploy(
    deployer.address, // Set the owner address to the deployer's address
    registry.address
  );
  await arbitration.deployed();
  console.log("Arbitration contract deployed to:", arbitration.address);

  // Deploy the Trade contract
  const trade = await Trade.deploy(registry.address);
  await trade.deployed();
  console.log("Trade contract deployed to:", trade.address);

  // Deploy the Offer contract
  const offer = await Offer.deploy(registry.address);
  await offer.deployed();
  console.log("Offer contract deployed to:", offer.address);

  // Deploy the Rating contract
  const rating = await Rating.deploy(registry.address);
  await rating.deployed();
  console.log("Rating contract deployed to:", rating.address);

  // Deploy the Reputation contract
  const reputation = await Reputation.deploy(registry.address);
  await reputation.deployed();
  console.log("Reputation contract deployed to:", reputation.address);

  // Update the ContractRegistry with the deployed contract addresses
  await registry.updateAddresses(
    account.address,
    offer.address,
    trade.address,
    escrow.address,
    rating.address,
    reputation.address,
    arbitration.address
  );
  console.log("ContractRegistry addresses updated");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
