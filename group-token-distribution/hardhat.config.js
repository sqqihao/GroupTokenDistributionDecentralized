require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: "https://eth-sepolia.g.alchemy.com/v2/1YybJp4OA3ZZDOrmhuzky8_MACPdghWu",
      accounts: [
	      "0xf4d494170f139d7cf029227585f61356acbf5a83fd3f192d63eb731f24584c1a",
	      "4412bebdc11f1ecee5db4f9356d0c58b0871896debd0bf5380402e398ef42948",
	      "438ce764cd074a5c40e7a5c4bb4b5b58dab9aea326766dc339105d23768eb1f5"
	  ]
    }
  }
};
