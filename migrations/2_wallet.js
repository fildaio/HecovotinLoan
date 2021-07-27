const HecoNodeVote = artifacts.require("HecoNodeVote");
const LoanViaFilda = artifacts.require("LoanViaFilda");
const HTToken = artifacts.require("HTToken");
const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");

module.exports = async function (deployer, network, accounts) {
	await deployer.deploy(HecoNodeVote);
	const hecoNodeVoteInstance = await HecoNodeVote.deployed();
	console.log("HecoNodeVote: ", HecoNodeVote.address);
	hecoNodeVoteInstance.setVoting("0x80d1769ac6fee59BE5AAC1952a90270bbd2Ceb2F");// for heco mainnet.

	await deployer.deploy(LoanViaFilda);
	const loanViaFildaInstance = await LoanViaFilda.deployed();
	console.log("LoanViaFilda: ", LoanViaFilda.address);
	loanViaFildaInstance.setCompContractAddress("0xE36FFD17B2661EB57144cEaEf942D95295E637F0");// for heco mainnet.
	loanViaFildaInstance.setComptrollerAddress("0xb74633f2022452f377403B638167b0A135DB096d");// for heco mainnet.
	loanViaFildaInstance.setCTokenAddress("0x824151251B38056d54A15E56B73c54ba44811aF8");// for heco mainnet.
	loanViaFildaInstance.setCompoundLens("0x824522f5a2584dCa56b1f05e6b41C584b3FDA4a3");// for heco mainnet.
	loanViaFildaInstance.setFlashLoan("0x824151251B38056d54A15E56B73c54ba44811aF8");// for heco mainnet.
	loanViaFildaInstance.setMaximillion("0x32fbB9c822ABd1fD9e4655bfA55A45285Fb8992d");// for heco mainnet.

	await deployer.deploy(HTToken, "100000000000000000000000000");
	console.log("HTToken: ", HTToken.address);

	await deployer.deploy(GlobalConfig);
	const globalConfigInstance = await GlobalConfig.deployed();
	console.log("GlobalConfig: ", GlobalConfig.address);
	globalConfigInstance.setVotingContract(HecoNodeVote.address);
	globalConfigInstance.setLoanContract(LoanViaFilda.address);
	globalConfigInstance.setHTToken(HTToken.address);
	globalConfigInstance.setFilda("0xE36FFD17B2661EB57144cEaEf942D95295E637F0");//for heco mainnet.

	await deployer.deploy(WalletFactory)
	console.log("WalletFactory: ", WalletFactory.address);
}