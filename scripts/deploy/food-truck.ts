import { ethers } from "hardhat";

async function main() {
  const FoodTruck = await ethers.getContractFactory("FoodTruck");
  const foodTruck = await FoodTruck.deploy(
    "0x49207Fcdd39E79253f68c2fD92dDd167E4Bda299",
    "https://my-nft-minter.vercel.app/api/metadata"
  );

  await foodTruck.deployed();

  console.log("FoodTruck deployed to:", foodTruck.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
