const { default: BigNumber } = require("bignumber.js");

const GlobalConfig = artifacts.require("GlobalConfig");
const WalletFactory = artifacts.require("WalletFactory");
const Wallet = artifacts.require("Wallet");

contract("WalletFactory and Wallet", async accounts => {
	const validator = "0xd36a0Ad934a1fc5BFaEf73c3678410e446a468C3";
	const depositAmount = 123456789;
	const borrowAmount = 12345678;

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

	it("GlobalConfig.comptrollerContract()", async () => {
		const result = await instanceGlobalConfig.comptrollerContract();
		assert.ok(result === "0xF0cb3D0424aAa3e63948D3F9aC964458BCfF3597", result);
	});

	it("Wallet.checkMembership()", async () => {
		theWallet = await Wallet.at(walletAddress);
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
		const voteAmount = new BigNumber(depositAmount);
		if (balanceBN.gt(voteAmount)) {
			await theWallet.vote(validator, {
				from: accounts[0],
				value: voteAmount.toString()
			});

			setTimeout(async () => {
				const userVotingSummary = await theWallet.getUserVotingSummary.call(validator);
				assert.ok(new BigNumber(userVotingSummary.amount).gte(depositAmount));
			}, 5000);
		} else {
			console.log("insufficient balance to vote.")
			assert.ok(true);
		}
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

	it("Wallet.getExchangeRate()", async () => {
		const exchangeRate = await theWallet.getExchangeRate.call();
		const exchangeRateBN = new BigNumber(exchangeRate).shiftedBy(18);
		console.log("exchangeRate:", exchangeRateBN.toFixed());
		assert.ok(exchangeRateBN.gte(0));
	});

	it("Wallet.getBorrowLimit()", async () => {
		const borrowLimit = await theWallet.getBorrowLimit.call();
		const borrowLimitBN = new BigNumber(borrowLimit);
		console.log("borrowLimit:", borrowLimitBN.toNumber());
		assert.ok(borrowLimitBN.gte(0));
	});

	it("Wallet.borrow()", async () => {
		await theWallet.borrow(borrowAmount);
	});

	it("Wallet.getBorrowed()", async () => {
		const borrowed = await theWallet.getBorrowed.call();
		const borrowedBN = new BigNumber(borrowed);
		console.log("borrowed:", borrowedBN.toNumber());
		assert.ok(borrowedBN.eq(borrowAmount));
	});

	it("Wallet.revokeVote()", async () => {
		const userVotingSummary = await theWallet.getUserVotingSummary.call(validator);
		if (userVotingSummary[0] && userVotingSummary[0] >= depositAmount) {
			const done = await theWallet.revokeVote(validator, depositAmount);
			assert.ok(done);
		} else {
			console.log("no voting.")
			assert.ok(true);
		}
	});

	// it("Wallet.withdrawVoting()", async () => {
	// 	const withdrawable = await theWallet.getUserVotingSummary.call(validator);
	// 	const currentBlock = await web3.eth.getBlock("latest");
	// 	if (new BigNumber(withdrawable.withdrawPendingAmount).comparedTo(depositAmount) >= 0 && (currentBlock.number - withdrawable.withdrawExitBlock) > 86400) {
	// 		await theWallet.withdrawVoting(validator);
	// 	} else {
	// 		console.log("the Pool is not withdrawable.");
	// 		assert.ok(true);
	// 	}
	// });

	// it("Wallet.withdrawAndRepay()", async () => {
	// 	const withdrawable = await theWallet.getUserVotingSummary.call(validator);
	// 	const currentBlock = await web3.eth.getBlock("latest");
	// 	if (new BigNumber(withdrawable.withdrawPendingAmount).comparedTo(depositAmount) >= 0 && (currentBlock.number - withdrawable.withdrawExitBlock) > 86400) {
	// 		await theWallet.withdrawAndRepay(validator);
	// 	} else {
	// 		console.log("the Pool is not withdrawable.");
	// 		assert.ok(true);
	// 	}
	// });

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
});