import { ethers } from "hardhat";

async function main() {
  const Employee = await ethers.getContractFactory("Employee");
  const employee = await Employee.deploy(
    "0x5355b99757A5bBDfCF88e4eDB2642067c35A6232"
  );

  await employee.deployed();

  console.log("Employee deployed to:", employee.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
