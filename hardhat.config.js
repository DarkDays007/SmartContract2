require("@nomicfoundation/hardhat-toolbox");

/** 
 * @type import('hardhat/config').HardhatUserConfig 
 */
module.exports = {
  solidity: "0.8.17",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    // Σύνδεση με το Ethereum mainnet μέσω Infura
    mainnet: {
      url: "https://mainnet.infura.io/v3/049cf2064820481baac53cd6b9c85b21",
      accounts: [
        // Πρόσεξε να το προστατεύεις, χρησιμοποίησε π.χ. dotenv σε πραγματική χρήση
        "0x304a22090a5994b84ea9d2591a829dafb777d40ecce5f2f6a48d93ac54856720"
      ]
    }
  }
};
