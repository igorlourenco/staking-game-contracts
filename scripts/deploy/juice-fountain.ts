import { ethers } from "hardhat";

async function main() {
  const JuiceFountain = await ethers.getContractFactory("JuiceFountain");
  const juiceFountain = await JuiceFountain.deploy();

  await juiceFountain.deployed();

  console.log("JuiceFountain deployed to:", juiceFountain.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
