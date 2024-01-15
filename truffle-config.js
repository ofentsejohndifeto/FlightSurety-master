var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    
    development: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 8545, // Standard Ethereum port (default: none)
      network_id: "*", // Any network (default: none)
      accounts: 50           // Establish 50 accounts in the dev network as recommended
    },

    ganache: {
      host: "127.0.0.1", // Localhost
      port: 8545, // Port for Ganache GUI
      network_id: 5777, // Match any network id
    },
  },
 
  compilers: {
    solc: {
      version: "0.4.25"
    }
  },
};