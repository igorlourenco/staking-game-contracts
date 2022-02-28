import { ethers } from "hardhat";

async function main() {
  const HotDoggeria = await ethers.getContractFactory("HotDoggeria");
  const hotDoggeria = await HotDoggeria.deploy(
    "0x1d91dD39B3DEfDcC5B77F933b25ec02131Cac63d",
    "0x8f81479fBf72D53b9A64C45db928b0Bb332003C2",
    "0x49207Fcdd39E79253f68c2fD92dDd167E4Bda299",
    "0xe49f90fb525bC39a9B84FfcCf78F61A759960e75",
    "0x237dEcaF67a3c64703577098D5817D7AE60E48D5"
  );

  await hotDoggeria.deployed();

  console.log("HotDoggeria deployed to:", hotDoggeria.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
