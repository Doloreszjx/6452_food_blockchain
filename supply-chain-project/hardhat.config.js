require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  paths: {
    sources: "./contracts",  // Solidity 合约文件夹
    tests: "./test",         // 测试文件夹
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
