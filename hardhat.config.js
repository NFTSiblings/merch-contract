require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.7",
  networks: {
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/731c65c5fa23442285d8eadf106f2bfb",
      accounts: ["5a0a487e36564f10a930591f0432aff3e4d5bcca026bca13feb7c20106948f19"]
    }
  },
  etherscan: {
    apiKey: "7H3W5RBZJQHBXZSM1G11AWKBSD356TNUJ1"
  }
};
