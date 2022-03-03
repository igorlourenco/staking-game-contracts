import { ethers } from "hardhat";

async function main() {
  // deploy HOTDOG
  const HotDog = await ethers.getContractFactory("HotDog");
  const hotDog = await HotDog.deploy();

  await hotDog.deployed();

  console.log("HotDog deployed to:", hotDog.address);

  //   await hre.run("verify:verify", {
  //     address: hotDog.address,
  //   });

  // deploy Food Truck
  const FoodTruck = await ethers.getContractFactory("FoodTruck");
  const foodTruck = await FoodTruck.deploy(
    hotDog.address,
    "https://my-nft-minter.vercel.app/api/metadata"
  );

  await foodTruck.deployed();

  console.log("FoodTruck deployed to:", foodTruck.address);

  //   await hre.run("verify:verify", {
  //     address: foodTruck.address,
  //     constructorArguments: [
  //       hotDog.address,
  //       "https://my-nft-minter.vercel.app/api/metadata",
  //     ],
  //   });

  // deploy Employee
  const Employee = await ethers.getContractFactory("Employee");
  const employee = await Employee.deploy(hotDog.address);

  await employee.deployed();

  console.log("Employee deployed to:", employee.address);

  //   await hre.run("verify:verify", {
  //     address: employee.address,
  //     constructorArguments: [hotDog.address],
  //   });

  // deploy Juice
  const Juice = await ethers.getContractFactory("Juice");
  const juice = await Juice.deploy();

  await juice.deployed();

  console.log("Juice deployed to:", juice.address);

  //   await hre.run("verify:verify", {
  //     address: juice.address,
  //   });

  // deploy JuiceFountain
  const JuiceFountain = await ethers.getContractFactory("JuiceFountain");
  const juiceFountain = await JuiceFountain.deploy();

  await juiceFountain.deployed();

  console.log("JuiceFountain deployed to:", juiceFountain.address);

  //   await hre.run("verify:verify", {
  //     address: juiceFountain.address,
  //   });

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

  //   await hre.run("verify:verify", {
  //     address: hotDoggeriaProgression.address,
  //     constructorArguments: [juice.address],
  //   });

  // deploy Upgrade
  const Upgrade = await ethers.getContractFactory("Upgrade");
  const upgrade = await Upgrade.deploy(
    hotDog.address,
    juice.address,
    "https://my-nft-minter.vercel.app/api/metadata/upgrade"
  );

  await upgrade.deployed();

  console.log("Upgrade deployed to:", upgrade.address);

  //   await hre.run("verify:verify", {
  //     address: upgrade.address,
  //     constructorArguments: [
  //       hotDog.address,
  //       juice.address,
  //       "https://my-nft-minter.vercel.app/api/metadata/upgrade",
  //     ],
  //   });

  // deploy HotDoggeria
  const HotDoggeria = await ethers.getContractFactory("HotDoggeria");
  const hotDoggeria = await HotDoggeria.deploy(
    foodTruck.address,
    upgrade.address,
    hotDog.address,
    juice.address,
    employee.address
  );

  await hotDoggeria.deployed();

  //   await hre.run("verify:verify", {
  //     address: hotDoggeria.address,
  //     constructorArguments: [
  //       foodTruck.address,
  //       upgrade.address,
  //       hotDog.address,
  //       juice.address,
  //       employee.address,
  //     ],
  //   });

  console.log("HotDoggeria deployed to:", hotDoggeria.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
