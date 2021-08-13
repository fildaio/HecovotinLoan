const Config = require("./Config");

const LoanViaFilda = artifacts.require("LoanViaFilda");
const HTToken = artifacts.require("HTToken");
const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");

module.exports = async function (deployer, network, accounts) {
	const theConfig = Config[network]

	await deployer.deploy(
		LoanViaFilda,
		theConfig.compContract,
		theConfig.compoundLens,
		theConfig.comptroller,
		theConfig.borrow
	);
	await LoanViaFilda.deployed();
	console.log("LoanViaFilda: ", LoanViaFilda.address);

	// const httInstance = await deployer.deploy(HTToken, "HT Token", "HTT");
	const httInstance = await HTToken.at(theConfig.htt);
	console.log("HTToken: ", HTToken.address);

	await deployer.deploy(
		GlobalConfig,
		accounts[0],
		theConfig.vote,
		LoanViaFilda.address,
		theConfig.deposit,
		theConfig.borrow,
		theConfig.compContract,
		theConfig.comptroller,
		theConfig.htt
		// HTToken.address
	);
	await GlobalConfig.deployed();
	console.log("GlobalConfig: ", GlobalConfig.address);

	await deployer.deploy(WalletFactory)
	console.log("WalletFactory: ", WalletFactory.address);

	httInstance.setFactory(WalletFactory.address);
}