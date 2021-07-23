const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");

contract("WalletFactory", accounts => {
	let config;
	let walletFactory;

	it("GlobalConfig", () => {
		return GlobalConfig.deployed().then(instanceGlobalConfig => {
			config = instanceGlobalConfig.address;

			return WalletFactory.deployed();
		}).then(instanceWalletFactory => {
			walletFactory = instanceWalletFactory;
			console.log("walletFactory: ", walletFactory.address);

			console.log("----------------------------------------")
			console.log("walletFactory.makeWallet()…… args:", config);
			return walletFactory.makeWallet(config);
		}).then(_ => {
			console.log("----------------------------------------")
			console.log("walletFactory.getWallet()…… args:", accounts[0]);
			return walletFactory.getWallet(accounts[0]);
		}).then(result => {
			console.log("walletFactory.getWallet() return:", result);

			console.log("----------------------------------------")
			console.log("walletFactory.getOwner() args:", result);
			return walletFactory.getOwner(result);
		}).then(owner => {
			console.log("walletFactory.getOwner() return:", owner);

			assert.equal(owner, accounts[0], "Account <==> Wallet");
		});
	});
});