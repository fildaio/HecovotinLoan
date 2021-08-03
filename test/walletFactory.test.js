const { default: BigNumber } = require("bignumber.js");

const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");
const Wallet = artifacts.require("Wallet");

contract("WalletFactory and Wallet", async accounts => {
	const validator = "0xd36a0Ad934a1fc5BFaEf73c3678410e446a468C3";

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
		assert.equal(allowance, 0,);
	});

	it("Wallet.checkMembership()", async () => {
		const checkMembership = await theWallet.checkMembership.call();
		assert.ok(checkMembership, "checkMembership() == false");
	});

	it("Wallet.getPendingRewardFilda()", async () => {
		const pendingRewardFilda = await theWallet.getPendingRewardFilda.call();
		const value = new BigNumber(pendingRewardFilda.allocated);
		assert.ok(value.gte(0), "pendingRewardFilda:" + value.toNumber());
	});

	it("Wallet.claimFilda()", async () => {
		await theWallet.claimFilda();
		const pendingRewardFilda = await theWallet.getPendingRewardFilda.call();
		const value = new BigNumber(pendingRewardFilda.allocated);
		console.log("pendingRewardFilda:", value.toNumber());
		assert.ok(value.eq(0), "pendingRewardFilda:" + value.toNumber());
	});

	it("Wallet.vote()", async () => {
		const balance = await web3.eth.getBalance(accounts[0]);
		const balanceBN = new BigNumber(balance);
		const voteAmount = new BigNumber("123456789");
		if (balanceBN.gt(voteAmount)) {
			await theWallet.vote(validator, {
				from: accounts[0],
				value: voteAmount.toString()
			});

			setTimeout(async () => {
				const userVotingSummary = await theWallet.getUserVotingSummary.call(validator);
				assert.ok(new BigNumber(userVotingSummary.amount).gte(123456789));
			}, 5000);
		} else {
			console.log("insufficient balance to vote.")
			assert.ok(true);
		}
	});

	it("Wallet.depositHTT()", async () => {
		await theWallet.depositHTT("1000000000000000000");
	});

	it("Wallet.pendingReward()", async () => {
		const pendingReward = await theWallet.pendingReward(validator);
		const pendingRewardBN = new BigNumber(pendingReward);
		assert.ok(pendingRewardBN.comparedTo(0) >= 0);
	});

	if ("Wallet.getUserVotingSummary", async () => {
		const userVotingSummary = await theWallet.getUserVotingSummary.call(validator);
		console.log("userVotingSummary:", userVotingSummary);
	});

	it("Wallet.revokeVote()", async () => {
		const userVotingSummary = await theWallet.getUserVotingSummary.call(validator);
		if (userVotingSummary[0] && userVotingSummary[0] >= 123456789) {
			const done = await theWallet.revokeVote(validator, "123456789");
			assert.ok(done);
		} else {
			console.log("no voting.")
			assert.ok(true);
		}
	});

	it("Wallet.getBorrowLimit()", async () => {
		const borrowLimit = await theWallet.getBorrowLimit.call();
		const borrowLimitBN = new BigNumber(borrowLimit);
		console.log("borrowLimit:", borrowLimitBN.toNumber());
		assert.ok(borrowLimitBN.gte(0));
	});

	it("Wallet.borrow()", async () => {
		const borrowAmount = "123456789";
		await theWallet.borrow(borrowAmount);
	});

	it("Wallet.withdrawVoting()", async () => {
		const withdrawable = await theWallet.getUserVotingSummary.call(validator);
		if (new BigNumber(withdrawable.withdrawPendingAmount).comparedTo(123456789) >= 0) {
			await theWallet.withdrawVoting(validator);
		} else {
			console.log("the Pool is not withdrawable.");
			assert.ok(true);
		}
	});

	it("Wallet.withdrawAndRepay()", async () => {
		const withdrawable = await theWallet.getUserVotingSummary.call(validator);
		if (new BigNumber(withdrawable.withdrawPendingAmount).comparedTo(123456789) >= 0) {
			await theWallet.withdrawAndRepay(validator);
		} else {
			console.log("the Pool is not withdrawable.");
			assert.ok(true);
		}
	});

	// it("Wallet.withdrawAndRepayAll()", async () => {
	// 	const userVotingSummary = await theWallet.getUserVotingSummary.call();
	// 	const allWithdrawable = true;
	// 	if (typeof userVotingSummary === "object" && userVotingSummary.length >= 0) {
	// 		for (i = 0; i < userVotingSummary.length; i++) {
	// 			const pid = userVotingSummary[0].pid;
	// 			const withdrawable = await theWallet.isWithdrawable.call(pid);
	// 			if (!withdrawable) {
	// 				allWithdrawable = false;
	// 				console.log("the pool #" + pid + " is not withdrawable");
	// 				break;
	// 			}
	// 		}
	// 	} else {
	// 		allWithdrawable = false;
	// 	}

	// 	if (allWithdrawable) {
	// 		await theWallet.withdrawAndRepayAll();
	// 	} else {
	// 		console.log("the pools are not withdrawable");
	// 		assert.ok(true);
	// 	}
	// });

	it("Wallet.repay()", async () => {
		await theWallet.repay({
			from: accounts[0],
			value: "123456789"
		});
	});
});