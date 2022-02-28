import { ethers } from "hardhat";

async function main() {
  const HotDog = await ethers.getContractFactory("HotDog");
  const hotDog = await HotDog.deploy();

  await hotDog.deployed();

  console.log("HotDog deployed to:", hotDog.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
