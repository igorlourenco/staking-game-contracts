import { ethers } from "hardhat";

async function main() {
  const FoodTruck = await ethers.getContractFactory("FoodTruck");
  const foodTruck = await FoodTruck.deploy(
    "0x49207Fcdd39E79253f68c2fD92dDd167E4Bda299",
    "0x50492D9c6B5cEe195fF89fee881b50Ff63F7CaD4",
    "https://my-nft-minter.vercel.app/api/metadata"
  );

  await foodTruck.deployed();

  console.log("FoodTruck deployed to:", foodTruck.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
