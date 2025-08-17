const hre = require("hardhat");

async function main() {
  const USDT_ADDRESS = "0x5De610ee1b9b6B9ad4f088d08bBB1D58F744296E"; // 真实或测试USDT地址
  const WETH_ADDRESS = "0x5De610ee1b9b6B9ad4f088d08bBB1D58F744296E"; // 真实或测试WETH地址
  const INTERVAL = 30 * 24 * 60 * 60; // 每30天发放一次

  const Distribution = await hre.ethers.getContractFactory("GroupTokenDistributionDecentralized");
  const distribution = await Distribution.deploy(USDT_ADDRESS, WETH_ADDRESS, INTERVAL);

  await distribution.waitForDeployment();
  console.log(`GroupTokenDistributionDecentralized deployed to: ${distribution.target}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
