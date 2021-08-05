const Config = require("./Config");

const LoanViaFilda = artifacts.require("LoanViaFilda");
const HTToken = artifacts.require("HTToken");
const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");

module.exports = async function (deployer, network, accounts) {
	const theConfig = Config[network]

	await deployer.deploy(LoanViaFilda);
	const loanViaFildaInstance = await LoanViaFilda.deployed();
	console.log("LoanViaFilda: ", LoanViaFilda.address);
	loanViaFildaInstance.setCompContractAddress(theConfig.compContract);
	loanViaFildaInstance.setCompoundLens(theConfig.compoundLens);
	loanViaFildaInstance.setComptrollerAddress(theConfig.comptroller);
	loanViaFildaInstance.setCTokenAddress(theConfig.cToken);// HT, for heco testnet.

	// const httInstance = await deployer.deploy(HTToken);
	const httInstance = await HTToken.at(theConfig.htt);
	console.log("HTToken: ", HTToken.address);

	await deployer.deploy(GlobalConfig);
	const globalConfigInstance = await GlobalConfig.deployed();
	console.log("GlobalConfig: ", GlobalConfig.address);
	globalConfigInstance.setVotingContract(theConfig.vote);
	globalConfigInstance.setLoanContract(LoanViaFilda.address);
	globalConfigInstance.setDepositContract(theConfig.deposit);
	globalConfigInstance.setBorrowContract(theConfig.borrow);
	globalConfigInstance.setFilda(theConfig.filda);
	globalConfigInstance.setComptrollerContract(theConfig.comptroller);
	globalConfigInstance.setCTokenContract(theConfig.cToken);
	// globalConfigInstance.setHTToken(HTToken.address);
	globalConfigInstance.setHTToken(theConfig.htt);

	await deployer.deploy(WalletFactory)
	console.log("WalletFactory: ", WalletFactory.address);

	httInstance.setFactory(WalletFactory.address);
}