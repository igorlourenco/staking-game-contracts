import { ethers } from "hardhat";

async function main() {
  const Juice = await ethers.getContractFactory("Juice");
  const juice = await Juice.deploy();

  await juice.deployed();

  console.log("Juice deployed to:", juice.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
