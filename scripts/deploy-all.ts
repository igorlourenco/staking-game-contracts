import { ethers } from "hardhat";

async function main() {
  // deploy HOTDOG
  const HotDog = await ethers.getContractFactory("HotDog");
  const hotDog = await HotDog.deploy();

  await hotDog.deployed();

  console.log("HotDog deployed to:", hotDog.address);

  // deploy Food Truck
  const FoodTruck = await ethers.getContractFactory("FoodTruck");
  const foodTruck = await FoodTruck.deploy(
    hotDog.address,
    "0x50492D9c6B5cEe195fF89fee881b50Ff63F7CaD4",
    "https://my-nft-minter.vercel.app/metadata"
  );

  await foodTruck.deployed();

  console.log("FoodTruck deployed to:", foodTruck.address);

  // deploy Freezer
  const Freezer = await ethers.getContractFactory("Freezer");
  const freezer = await Freezer.deploy(hotDog.address);

  await freezer.deployed();

  console.log("Freezer deployed to:", freezer.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
