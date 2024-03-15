const { ethers } = require("hardhat");

async function main() {
  // Get the deployed ContractRegistry instance
  const contractRegistryAddress = "0x26282F41dFBA4396BC82418e8aD9e43682afF064";
  const ContractRegistry = await ethers.getContractFactory("ContractRegistry");
  const registry = await ContractRegistry.attach(contractRegistryAddress);

  // Get the deployed Account contract instance
  const accountAddress = await registry.accountAddress();
  const Account = await ethers.getContractFactory("Account");
  const account = await Account.attach(accountAddress);

  // Get the deployer's address
  const [deployer] = await ethers.getSigners();

  // Register the user
  // await account.userReg(
  //   ethers.utils.formatBytes32String("me@georgedonnelly.com"), // Email
  //   ethers.utils.formatBytes32String("georgedonnelly"), // Chat handle
  //   ethers.utils.formatBytes32String("https://georgedonnelly.com"), // Website
  //   "https://static.panmoni.org/georgedonnellycom/georgedonnelly.jpg" // Avatar URL
  // );

  // Set the deployer as an admin
  const adminRole = "admin"; // Specify the admin role
  await account.userUpdateProfile(
    ethers.utils.formatBytes32String("me@georgedonnelly.com"), //  email
    ethers.utils.formatBytes32String("georgedonnelly"), // chat handle
    ethers.utils.formatBytes32String("https://georgedonnelly.com"), // website
    "https://static.panmoni.org/georgedonnellycom/georgedonnelly.jpg", // avatar URL
    adminRole
  );

  console.log("Admin role assigned to:", deployer.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
