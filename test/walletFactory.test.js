const { BN } = require("bn.js");

const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");
const Wallet = artifacts.require("Wallet");

contract("WalletFactory and Wallet", async accounts => {
	let instanceGlobalConfig;
	let instanceWalletFactory;
	let walletAddress = "";
	let theWallet = null;

	it("WalletFactory.makeWallet()", async () => {
		instanceGlobalConfig = await GlobalConfig.deployed();
		instanceWalletFactory = await WalletFactory.deployed();
		await instanceWalletFactory.makeWallet(instanceGlobalConfig.address);

		walletAddress = await instanceWalletFactory.getWallet(accounts[0]);
		console.log("walletAddress: ", walletAddress);

		const owner = await instanceWalletFactory.getOwner(walletAddress);
		console.log("owner: ", owner);

		assert.equal(owner, accounts[0]);
	});

	it("Wallet.allowance()", async () => {
		theWallet = await Wallet.at(walletAddress);
		assert.ok(theWallet);

		const allowance = await theWallet.allowance();
		assert.equal(allowance, 0);
	});

	it("Wallet.getBorrowLimit()", async () => {
		const borrowLimit = await theWallet.getBorrowLimit.call();
		const borrowLimitBN = new BN(borrowLimit);
		assert.ok(borrowLimitBN.gte(0));
	});

	it("Wallet.getPendingRewardFilda()", async () => {
		const pendingRewardFilda = await theWallet.getPendingRewardFilda.call();
		const value = new BN(pendingRewardFilda.allocated);
		assert.ok(value.gte(0));
	});

	it("Wallet.claimFilda()", async () => {
		await theWallet.claimFilda();
		const pendingRewardFilda = await theWallet.getPendingRewardFilda.call();
		const value = new BN(pendingRewardFilda.allocated);
		assert.ok(value.eq(0));
	});
});