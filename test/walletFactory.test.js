const { default: BigNumber } = require("bignumber.js");

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

	it("Wallet.VOTE_UNIT()", async () => {
		const unit = await theWallet.VOTE_UNIT.call();
		const value = new BigNumber(unit);
		console.log("VOTE_UNIT:", value.toNumber());
		assert.ok(value.gt(0));
	});

	it("Wallet.vote()", async () => {
		const balance = await web3.eth.getBalance(accounts[0]);
		const balanceBN = new BigNumber(balance);
		const voteAmount = new BigNumber("1100000000000000000");
		if (balanceBN.gt(voteAmount)) {
			await theWallet.vote(17, {
				from: accounts[0],
				value: voteAmount.toString()
			});

			setTimeout(async () => {
				const userVotingSummary = await theWallet.getUserVotingSummary.call();
				assert.ok(typeof userVotingSummary === "object" && userVotingSummary.length >= 0 && userVotingSummary[0] && userVotingSummary[0].pid && parseInt(userVotingSummary[0].pid) == 17);
			}, 15000);
		} else {
			console.log("insufficient balance to vote.")
			assert.ok(true);
		}
	});

	it("Wallet.depositHTT()", async () => {
		await theWallet.depositHTT("1000000000000000000");
	});

	it("Wallet.pendingReward()", async () => {
		const pendingReward = await theWallet.pendingReward(17);
		const pendingRewardBN = new BigNumber(pendingReward);
		assert.ok(pendingRewardBN.comparedTo(0) >= 0);
	});

	it("Wallet.claim()", async () => {
		let pendingReward = await theWallet.pendingReward(17);
		let pendingRewardBN = new BigNumber(pendingReward);
		if (pendingRewardBN.comparedTo(0) > 0) {
			await theWallet.claim(17);

			setTimeout(async () => {
				pendingReward = await theWallet.pendingReward(17);
				pendingRewardBN = new BigNumber(pendingReward);
				assert.ok(pendingRewardBN.comparedTo(0) === 0);
			}, 15000);
		} else {
			assert.ok(true);
		}
	});

	if ("Wallet.getUserVotingSummary", async () => {
		const userVotingSummary = await theWallet.getUserVotingSummary.call();//0xe4a28e4c0A67BF36C22CC4A0F573B4256b697B3f for test...
		assert.ok(typeof userVotingSummary === "object" && userVotingSummary.length >= 0);
	});

	it("Wallet.revokeVote()", async () => {
		const userVotingSummary = await theWallet.getUserVotingSummary.call();//0xe4a28e4c0A67BF36C22CC4A0F573B4256b697B3f for test...
		if (typeof userVotingSummary === "object" && userVotingSummary.length >= 0 && userVotingSummary[0] && userVotingSummary[0].pid && parseInt(userVotingSummary[0].pid) == 17) {
			const done = await theWallet.revokeVote(17, "1000000000000000000");
			assert.ok(done);
		} else {
			console.log("no voting.")
			assert.ok(true);
		}
	});

	it("Wallet.getBorrowLimit()", async () => {
		const borrowLimit = await theWallet.getBorrowLimit.call();
		const borrowLimitBN = new BigNumber(borrowLimit);
		assert.ok(borrowLimitBN.gte(0));
	});

	it("Wallet.borrow()", async () => {
		const borrowAmount = "10000000000000000";
		await theWallet.borrow(borrowAmount);
	});

	it("Wallet.revokingInfo()", async () => {
		const revokingInfo = await theWallet.revokingInfo.call(17);
		assert.ok(typeof revokingInfo === "object" && revokingInfo["0"]);
	});

	it("Wallet.isWithdrawable()", async () => {
		const done = await theWallet.isWithdrawable.call(17);
		console.log("the pool #17 isWithdrawable:", done);
	});

	it("Wallet.withdrawVoting()", async () => {
		const withdrawable = await theWallet.isWithdrawable.call(17);
		if (withdrawable) {
			const withdrawal = await theWallet.withdrawVoting(17);
			console.log("withdrawal:", withdrawal);
		} else {
			console.log("the Pool #17 is not withdrawable.");
			assert.ok(true);
		}
	});

	it("Wallet.withdrawAndRepay()", async () => {
		const withdrawable = await theWallet.isWithdrawable.call(17);
		if (withdrawable) {
			const withdrawal = await theWallet.withdrawAndRepay(17);
			console.log("withdrawal:", withdrawal);
		} else {
			console.log("the Pool #17 is not withdrawable.");
			assert.ok(true);
		}
	});

	it("Wallet.withdrawAndRepayAll()", async () => {
		const userVotingSummary = await theWallet.getUserVotingSummary.call();
		const allWithdrawable = true;
		if (typeof userVotingSummary === "object" && userVotingSummary.length >= 0) {
			for (i = 0; i < userVotingSummary.length; i++) {
				const pid = userVotingSummary[0].pid;
				const withdrawable = await theWallet.isWithdrawable.call(pid);
				if (!withdrawable) {
					allWithdrawable = false;
					console.log("the pool #" + pid + " is not withdrawable");
					break;
				}
			}
		} else {
			allWithdrawable = false;
		}

		if (allWithdrawable) {
			await theWallet.withdrawAndRepayAll();
		} else {
			console.log("the pools are not withdrawable");
			assert.ok(true);
		}
	});

	it("Wallet.repay()", async () => {
		await theWallet.repay({
			from: accounts[0],
			value: "10000000000000000"
		});
	});
});