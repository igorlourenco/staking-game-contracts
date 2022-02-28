import { ethers } from "hardhat";

async function main() {
  const Freezer = await ethers.getContractFactory("Freezer");
  const freezer = await Freezer.deploy(
    "0x5355b99757A5bBDfCF88e4eDB2642067c35A6232"
  );

  await freezer.deployed();

  console.log("Freezer deployed to:", freezer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
