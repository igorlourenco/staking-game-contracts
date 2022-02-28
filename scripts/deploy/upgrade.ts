import { ethers } from "hardhat";

async function main() {
  const Upgrade = await ethers.getContractFactory("Upgrade");
  const upgrade = await Upgrade.deploy(
    "0x49207Fcdd39E79253f68c2fD92dDd167E4Bda299",
    "0xe49f90fb525bC39a9B84FfcCf78F61A759960e75",
    "https://my-nft-minter.vercel.app/metadata/upgrade"
  );

  await upgrade.deployed();

  console.log("Upgrade deployed to:", upgrade.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
