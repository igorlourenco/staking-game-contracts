import { ethers } from "hardhat";

async function main() {
  const FoodTruck = await ethers.getContractFactory("FoodTruck");
  const foodTruck = await FoodTruck.deploy(
    "0x5355b99757A5bBDfCF88e4eDB2642067c35A6232",
    "0x50492D9c6B5cEe195fF89fee881b50Ff63F7CaD4",
    "https://my-nft-minter.vercel.app/metadata"
  );

  await foodTruck.deployed();

  console.log("FoodTruck deployed to:", foodTruck.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
