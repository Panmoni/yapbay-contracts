// @/scripts/justDeployOfferRegistry.js
const { ethers } = require("hardhat");

// generates an error with contract registery regard deployer vs owner

async function main() {
  // Get the contract factories
  const Offer = await ethers.getContractFactory("Offer");

  const [owner] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", owner.address);

  // Set the ContractRegistry address (replace with the actual address)
  const registryAddress = "0x26282F41dFBA4396BC82418e8aD9e43682afF064";

  // Deploy the updated Offer contract
  const offer = await Offer.deploy(registryAddress);
  await offer.deployed();
  console.log("Updated Offer contract deployed to:", offer.address);

  // Get the ContractRegistry contract instance
  const ContractRegistry = await ethers.getContractFactory("ContractRegistry");
  const registry = await ContractRegistry.attach(registryAddress);

  // await hre.run("debug", { tx: "<transaction-hash>" });

  // Update the Offer contract address in the ContractRegistry
  await registry.updateOfferAddress(offer.address, { gasLimit: 500000 });
  console.log("ContractRegistry Offer address updated", registry.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
