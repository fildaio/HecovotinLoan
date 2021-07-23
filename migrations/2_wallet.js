// const Migrations = artifacts.require("Migrations");

// module.exports = function (deployer) {
//   deployer.deploy(Migrations);
// };

// const FlashLoan = artifacts.require("FlashLoan");

// module.exports = async function (deployer, network, accounts) {
//   await deployer.deploy(FlashLoan,
//     '0x', // _governance
//     '0x', // comptroller
//     '0x', // oracle
//     '0x', // fHUSD
//     '0x' // WHT
//   );

//   console.log("***********************************************");
//   console.log("FlashLoan address:", FlashLoan.address);
//   console.log("***********************************************");
// };

const WalletFactory = artifacts.require("WalletFactory");
const GlobalConfig = artifacts.require("GlobalConfig");

module.exports = async function (deployer, network, accounts) {
	await deployer.deploy(GlobalConfig);
	console.log("GlobalConfig: ", GlobalConfig.address);

	await deployer.deploy(WalletFactory)
	console.log("WalletFactory: ", WalletFactory.address);
}