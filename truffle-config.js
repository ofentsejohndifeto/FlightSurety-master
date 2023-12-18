var HDWalletProvider = require("@truffle/hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    
    development: {
      host: "127.0.0.1", // Localhost (default: none)
      port: 9545, // Standard Ethereum port (default: none)
      network_id: "*", // Any network (default: none)
    },

    ganache: {
      host: "127.0.0.1", // Localhost
      port: 8545, // Port for Ganache GUI
      network_id: "*", // Match any network id
    },
  },
 
  compilers: {
    solc: {
      version: "0.4.25"
    }
  },
};