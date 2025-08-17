const hre = require("hardhat");

// 延迟函数
async function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
async function main() {
  const { ethers } = hre;

  const [owner, alice, bob] = await ethers.getSigners();
  // console.log([owner, alice, bob]);

  const ownerAddress = await owner.getAddress();
  const aliceAddress = await alice.getAddress();
  const bobAddress = await bob.getAddress();

  console.log("Deploying contracts with owner:", ownerAddress);
  console.log("alice address:", aliceAddress);
  console.log("bob address:", bobAddress);

  // 1. 部署 Mock USDT 和 WETH
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const usdt = await MockERC20.deploy("Mock USDT", "USDT", ethers.parseUnits("1000000", 6),6);
  const weth = await MockERC20.deploy("Mock WETH", "WETH", ethers.parseUnits("1000000", 18),18);
  await usdt.waitForDeployment();
  await weth.waitForDeployment();

  console.log("Mock USDT deployed:", usdt.target);
  console.log("Mock WETH deployed:", weth.target);

  // 2. 部署分配合约
  const Distribution = await ethers.getContractFactory("GroupTokenDistributionDecentralized");
  const distribution = await Distribution.deploy(usdt.target, weth.target, 60);
  await distribution.waitForDeployment();

  console.log("Distribution deployed:", distribution.target);

  // 3. 添加受益人
  await distribution.addBeneficiary(aliceAddress, 5000); //5000就是50%
  await distribution.addBeneficiary(bobAddress, 5000); //5000就是50%
  console.log("Added Alice & Bob as beneficiaries");

  // 4. 给合约充值
  await usdt.transfer(distribution.target, ethers.parseUnits("1000000", 6));
  await weth.transfer(distribution.target, ethers.parseUnits("5", 18));
  console.log("Funded contract with USDT & WETH");

  console.log("4秒后执行");
  await delay(4000); // 延迟 4 秒

  // 5. 发放 USDT
  // await distribution.distributeUSDT({ gasLimit: 500000 });;
  // console.log("Distributed USDT");

  // 6. 发放 WETH
  await distribution.distributeWETH({ gasLimit: 500000 });;
  console.log("Distributed WETH");

  console.log("执行完毕");
/*
  // 7. 锁定合约
  await distribution.lockContract();
  console.log("Contract locked");

  // 8. 尝试修改（应失败）
  try {
    await distribution.addBeneficiary(ownerAddress, 1000);
  } catch (error) {
    console.log("Modification after lock failed as expected");
  }
*/
  console.log("Test completed ✅");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

/*
Deploying contracts with owner: 0xa66085862483Fb334a5A1172D3Bc93974B40A24a
alice address: 0x132e56C425EC23414465FC76f1D337Ae0eFB5420
bob address: 0xf604A6a52352D19E3Fd7e00A0eb48C27acBFb043

Mock USDT deployed: 0x9e9AC79ca75b729FcA3690c9A10846cE8c58ad42
Mock WETH deployed: 0x2C3d70c0E0f9a0dF864F9AC6CbE9683252bbcc7d

分配合约Distribution deployed: 0x0AB77C2C2E8035082420B429C5F9415E5ecF7844
Added Alice & Bob as beneficiaries
Funded contract with USDT & WETH
Distributed USDT
Distributed WETH
Contract locked
Test completed ✅
*/