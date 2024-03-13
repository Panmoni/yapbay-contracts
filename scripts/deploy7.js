const { ethers } = require("hardhat");

async function main() {
  // Get the contract factories
  const Account = await ethers.getContractFactory("Account");
  const Offer = await ethers.getContractFactory("Offer");
  const Trade = await ethers.getContractFactory("Trade");
  const Escrow = await ethers.getContractFactory("Escrow");
  const Rating = await ethers.getContractFactory("Rating");
  const Reputation = await ethers.getContractFactory("Reputation");
  const Arbitration = await ethers.getContractFactory("Arbitration");

  // Deploy the Account contract
  const account = await Account.deploy();
  await account.deployed();
  console.log("Account contract deployed to:", account.address);

  // Deploy the Offer contract
  const offer = await Offer.deploy(trade.address);
  await offer.deployed();
  console.log("Offer contract deployed to:", offer.address);

  // Deploy the Trade contract
  const trade = await Trade.deploy(
    offer.address,
    escrow.address,
    arbitration.address,
    rating.address
  );
  await trade.deployed();
  console.log("Trade contract deployed to:", trade.address);

  // Deploy the Escrow contract
  const escrow = await Escrow.deploy(
    admin.address,
    trade.address,
    arbitration.address,
    platformFeePercentage,
    penaltyPercentage
  );
  await escrow.deployed();
  console.log("Escrow contract deployed to:", escrow.address);

  // Deploy the Rating contract
  const rating = await Rating.deploy(
    trade.address,
    offer.address,
    account.address
  );
  await rating.deployed();
  console.log("Rating contract deployed to:", rating.address);

  // Deploy the Reputation contract
  const reputation = await Reputation.deploy(account.address);
  await reputation.deployed();
  console.log("Reputation contract deployed to:", reputation.address);

  // Deploy the Arbitration contract
  const arbitration = await Arbitration.deploy(
    admin.address,
    trade.address,
    escrow.address,
    account.address
  );
  await arbitration.deployed();
  console.log("Arbitration contract deployed to:", arbitration.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
