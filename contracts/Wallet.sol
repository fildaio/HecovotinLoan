// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./VotingStrategy.sol";
import "./LoanStrategy.sol";
import "./HTTokenInterface.sol";
import "./Global.sol";

contract Wallet is AccessControl, Global {
	using SafeMath for uint256;

	struct RedeemingState {
		uint256 blockNumber;
		uint256 amount;
	}

	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
	bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

	VotingStrategy public votingContract;
	LoanStrategy public loanContract;
	bool public isExist = false;

	address private _owner;
	uint256 private _minVoteAmount = 1e18;
	uint256 private _denominator = 10000;
	uint256 private _borrowRate = 8000;
	uint256 private _borrowQuicklyRate = 9800;
	uint256 private _liquidateRate = 9000;
	uint256 private _bonusRateForLiquidater = 3;
	address private _firstLiquidater;
	address private _secondLiquidater;
	address payable private _deployedVoteContract = payable(address(0x123));
	address payable private _deployedLoanContract = payable(address(0x123));
	HTTokenInterface private _HTT = HTTokenInterface(address(0x123));

	// Events
	event voteEvent(address voter, uint256 pid, uint256 amount);

	modifier isLiquidating(bool isOrNot) {
		if (isOrNot == false) {
			require(msg.sender == _owner);
		}
		_;
	}

	constructor(address owner) {
		_setupRole(ADMIN_ROLE, msg.sender);
		_setupRole(CONFIG_ROLE, msg.sender);

		isExist = true;

		_owner = owner;
		votingContract = VotingStrategy(_deployedVoteContract);
		loanContract = LoanStrategy(_deployedLoanContract);
	}

	function setConfigRole(address configRoleAddress) public {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
		_setupRole(CONFIG_ROLE, configRoleAddress);
	}

	function vote(uint256 pid) public payable {
		uint256 amount = msg.value;
		require(amount >= _minVoteAmount);

		address payable caller = payable(msg.sender);

		uint256 integerAmount = amount.div(_minVoteAmount).mul(_minVoteAmount);
		uint256 difference = amount.sub(integerAmount);
		if (difference > 0) {
			caller.transfer(difference);
		}

		bool done = votingContract.vote{ value: integerAmount }(pid);
		if (done == true) {
			uint256 oldBalance = _HTT.balance(address(this));
			bool mintHTTResult = _HTT.mint(integerAmount);
			if (mintHTTResult == false) {
				revert(); //"Failed to mint HTT."
			}

			uint256 newBalance = _HTT.balance(address(this));

			if (newBalance.sub(oldBalance) == integerAmount) {
				uint256 mintResult = loanContract.mint(integerAmount);
				if (mintResult > 0) {
					emit voteEvent(caller, pid, integerAmount);
				} else {
					revert(); //"Failed to deposit HT into Filda."
				}
			} else {
				revert(); //"Failed to mint HTT with the correct amount."
			}
		} else {
			revert(); //"Failed to vote."
		}
	}

	function getBorrowLimit() public returns (uint256) {
		return loanContract.getSavingBalance(address(this)).mul(_borrowRate).div(_denominator);
	}

	function getLiquidateLimit() public returns (uint256) {
		return loanContract.getSavingBalance(address(this)).mul(_liquidateRate).div(_denominator);
	}

	function borrow(uint256 borrowAmount) public {
		require(borrowAmount > 0);
		require(borrowAmount <= getLiquidateLimit().sub(loanContract.borrowBalanceCurrent(address(this))));

		uint256 borrowed = loanContract.borrow(borrowAmount);
		if (borrowed > 0) {
			payable(msg.sender).transfer(borrowed);
		} else {
			revert(); //"Failed to borrow from Filda."
		}
	}

	function claim(uint256 pid) public {
		require(votingContract.pendingReward(pid) > 0, "No rewards to claim.");

		uint256 oldBalance = address(this).balance;
		bool done = votingContract.claimReward(pid);
		if (done == true) {
			uint256 newBalance = address(this).balance;
			uint256 rewardToClaim = newBalance.sub(oldBalance);
			if (rewardToClaim > 0) {
				payable(msg.sender).transfer(rewardToClaim);
			} else {
				revert(); //"Insufficient reward amount."
			}
		} else {
			revert(); //"Failed to claim rewards."
		}
	}

	function revokeVote(uint256 pid, uint256 amount) public returns (bool success) {
		return votingContract.revokeVote(pid, amount);
	}

	function revokingInfo(uint256 pid)
		public
		returns (
			uint256,
			uint8,
			uint256
		)
	{
		return votingContract.revokingInfo(address(this), pid);
	}

	// function revokingDone(uint256 pid) public returns (bool) {
	// 	uint256 lockingEndTime;
	// 	(, , lockingEndTime) = votingContract.revokingInfo(address(this), pid);
	// 	bool withdrawable = isWithdrawable(pid);
	// 	if (lockingEndTime < block.timestamp && withdrawable == true) {
	// 		return true;
	// 	} else {
	// 		return false;
	// 	}
	// }

	// 检查已发起的撤回投票是否完成。
	// 不存在已发起的撤回投票，以及有未完成的撤回投票，都会返回false。
	function isRevokingAllDone() public returns (bool allDone) {
		VotingData[] memory votingDatas = votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				(uint256 amount, , uint256 lockingEndTime) = revokingInfo(votedData.pid);
				if (lockingEndTime > block.timestamp && isWithdrawable(votedData.pid) && amount < votedData.ballot) {
					allDone = false;
				}

				allDone = true;
			}
		}
	}

	function isWithdrawable(uint256 pid) public returns (bool) {
		return votingContract.isWithdrawable(address(this), pid);
	}

	// 负责从投票合约里把HT取出到钱包中。
	// 第二个参数thenTransafer为true时可以在提取后直接把HT转到用户帐户中。
	// 如果不这样做的话，那么在调用这个function成功的地方需要把已提取出的HT转到用户帐户中。这样方便批量从投票合约中提取，并一次性转帐给用户。
	function withdrawVoting(uint256 pid, bool thenTransafer) public returns (uint256 withdrawal) {
		require(msg.sender == _owner);
		require(isWithdrawable(pid) == true);

		uint256 oldBalance = address(this).balance;
		bool done = votingContract.withdraw(pid);
		if (done == true) {
			uint256 newBalance = address(this).balance;
			withdrawal = newBalance.sub(oldBalance);

			if (thenTransafer == true) {
				payable(msg.sender).transfer(withdrawal);
			}
		} else {
			revert(); //"Failed to withdraw from Heco voting."
		}
	}

	function repay() public payable {
		uint256 repayAmount = msg.value;
		require(repayAmount > 0);
		require(repayAmount <= loanContract.borrowBalanceCurrent(address(this)));
		require(msg.sender.balance >= repayAmount);

		bool done = loanContract.repayBehalf{ value: msg.value }(address(this));
		if (done == false) {
			revert(); //"Failed to repay."
		}
	}

	function revokeAll() public {
		require(msg.sender == _owner);
		_revokeAll(false);
	}

	function revokeVotingAndRepay() public {
		require(msg.sender == _owner);
		require(isRevokingAllDone() == true, "Revoking vote is in progress...");
		uint256 amount = _withdrawAllVoting(false);

		require(address(this).balance >= amount);
		loanContract.repayBehalf{ value: amount }(address(this));

		_withdrawAndBurnHTTFromFilda();
	}

	function withdrawAllVoting() public returns (uint256 totalAmount) {
		return _withdrawAllVoting(false);
	}

	function withdraw() public payable {
		require(msg.sender == _owner);

		uint256 HTBalance = address(this).balance;
		require(HTBalance > 0);

		uint256 amountToWithdraw = HTBalance.sub(loanContract.borrowBalanceCurrent(address(this)));
		// 在批量撤回后，一起再把HT转给用户。
		payable(msg.sender).transfer(amountToWithdraw);

		_withdrawAndBurnHTTFromFilda();
	}

	function liquidate() public payable {
		uint256 borrowBalanceCurrentAmount = loanContract.borrowBalanceCurrent(address(this));
		uint256 savingBalance = loanContract.getSavingBalance(address(this));
		uint256 borrowed = borrowBalanceCurrentAmount.mul(_denominator).div(savingBalance);
		require(borrowed > _borrowRate || borrowed > _liquidateRate);
		require(msg.sender != _owner);

		if (isRevokingAllDone() == false) {
			// isRevokingAllDone()返回false，说明尚未发起撤回全部投票，则调用_revokeAll(true)去撤回全部投票的全部数量。

			// Step 1: revoke all votes.
			_revokeAll(true);
			_firstLiquidater = msg.sender;
		} else {
			// Step 2: withdraw all.
			require(msg.value >= borrowBalanceCurrentAmount);

			uint256 total = _withdrawAllVoting(true);

			// 已把所有的投票撤回，HT在当前钱包中，继续用它还掉Filda的债务。
			loanContract.repayBehalf{ value: borrowBalanceCurrentAmount }(address(this));

			_secondLiquidater = msg.sender;

			_withdrawAndBurnHTTFromFilda();

			uint256 bonus = total.mul(_bonusRateForLiquidater).div(_denominator).div(2);
			payable(_firstLiquidater).transfer(bonus);
			payable(_secondLiquidater).transfer(bonus);
		}
	}

	function withdrawQuickly() public {
		uint256 savingBalance = loanContract.getSavingBalance(address(this));
		uint256 borrowAmount = savingBalance.mul(_borrowQuicklyRate).div(_denominator).sub(loanContract.borrowBalanceCurrent(address(this)));
		borrow(borrowAmount);
	}

	// 撤回全部投票的全部量，只供清算时内部调用。
	function _revokeAll(bool forLiquidation) private isLiquidating(forLiquidation) returns (bool allDone) {
		VotingData[] memory votingDatas = votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				bool success = revokeVote(votedData.pid, votedData.ballot);
				if (success == false) {
					revert(); //"Failed to revoke one of votings"
				}
				allDone = true;
			}
		}
	}

	function _withdrawAllVoting(bool forLiquidation) private isLiquidating(forLiquidation) returns (uint256 totalAmount) {
		VotingData[] memory votingDatas = votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				withdrawVoting(votedData.pid, false);
				totalAmount += votedData.ballot;
			}
		}
	}

	// 从Filda里提取出已抵押的HTT并销毁。
	function _withdrawAndBurnHTTFromFilda() public returns (uint256) {
		uint256 savingBalance = loanContract.getSavingBalance(address(this)).sub(loanContract.borrowBalanceCurrent(address(this)));
		if (savingBalance > 0) {
			uint256 result = loanContract.redeemUnderlying(savingBalance);
			if (result > 0) {
				if (_HTT.burn(result) == false) {
					revert(); //"Failed to burn HTT"
				}
				return result;
			} else {
				revert(); //"Failed to withdraw from Filda"
			}
		} else {
			revert(); //"No deposited HTT."
		}
	}
}
