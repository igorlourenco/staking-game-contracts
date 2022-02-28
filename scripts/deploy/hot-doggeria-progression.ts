import { ethers } from "hardhat";

async function main() {
  const HotDoggeriaProgression = await ethers.getContractFactory(
    "HotDoggeriaProgression"
  );
  const hotDoggeriaProgression = await HotDoggeriaProgression.deploy(
    "0xe49f90fb525bC39a9B84FfcCf78F61A759960e75"
  );

  await hotDoggeriaProgression.deployed();

  console.log(
    "HotDoggeriaProgression deployed to:",
    hotDoggeriaProgression.address
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
