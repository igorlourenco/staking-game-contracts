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
    "https://my-nft-minter.vercel.app/metadata/foodtruck"
  );

  await foodTruck.deployed();

  console.log("FoodTruck deployed to:", foodTruck.address);

  // deploy Freezer
  const Freezer = await ethers.getContractFactory("Freezer");
  const freezer = await Freezer.deploy(hotDog.address);

  await freezer.deployed();

  console.log("Freezer deployed to:", freezer.address);

  // deploy Juice
  const Juice = await ethers.getContractFactory("Juice");
  const juice = await Juice.deploy();

  await juice.deployed();

  console.log("Juice deployed to:", juice.address);

  // deploy JuiceFountain
  const JuiceFountain = await ethers.getContractFactory("JuiceFountain");
  const juiceFountain = await JuiceFountain.deploy();

  await juiceFountain.deployed();

  console.log("JuiceFountain deployed to:", juiceFountain.address);

  // deploy HotDoggeriaProgression
  const HotDoggeriaProgression = await ethers.getContractFactory(
    "HotDoggeriaProgression"
  );
  const hotDoggeriaProgression = await HotDoggeriaProgression.deploy(
    juice.address
  );

  await hotDoggeriaProgression.deployed();

  console.log(
    "HotDoggeriaProgression deployed to:",
    hotDoggeriaProgression.address
  );

  // deploy Upgrade
  const Upgrade = await ethers.getContractFactory("Upgrade");
  const upgrade = await Upgrade.deploy(
    hotDog.address,
    juice.address,
    "https://my-nft-minter.vercel.app/metadata/upgrade"
  );

  await upgrade.deployed();

  console.log("Upgrade deployed to:", upgrade.address);

  // deploy HotDoggeria
  const HotDoggeria = await ethers.getContractFactory("HotDoggeria");
  const hotDoggeria = await HotDoggeria.deploy(
    foodTruck.address,
    upgrade.address,
    hotDog.address,
    juice.address,
    freezer.address
  );

  await hotDoggeria.deployed();

  console.log("HotDoggeria deployed to:", hotDoggeria.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
