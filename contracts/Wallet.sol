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
	uint256 private _denominator = 100;
	uint256 private _borrowRate = 80;
	uint256 private _borrowQuicklyRate = 98;
	uint256 private _liquidateRate = 90;
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
			_HTT.mint(integerAmount);
			uint256 newBalance = _HTT.balance(address(this));

			if (newBalance.sub(oldBalance) >= integerAmount) {
				loanContract.mint(integerAmount);
				emit voteEvent(caller, pid, integerAmount);
			} else {
				revert("Failed to mint HTT with the correct amount.");
			}
		} else {
			revert("Failed to vote.");
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
		require(borrowAmount <= getBorrowLimit() || borrowAmount <= getLiquidateLimit());

		loanContract.borrow(borrowAmount);
		payable(msg.sender).transfer(borrowAmount);
	}

	function claim(uint256 pid) public {
		uint256 pendingReward = votingContract.pendingReward(pid);
		require(pendingReward > 0, "No rewards to claim.");

		uint256 oldBalance = address(this).balance;

		bool done = votingContract.claimReward(pid);
		if (done == true) {
			uint256 newBalance = address(this).balance;
			if (newBalance.sub(oldBalance) >= pendingReward) {
				payable(msg.sender).transfer(pendingReward);
			} else {
				revert("Insufficient reward amount.");
			}
		} else {
			revert("Failed to claim rewards.");
		}
	}

	function revokeVote(uint256 pid, uint256 amount) public returns (bool success) {
		uint256 tempAmount;
		(tempAmount, , ) = votingContract.revokingInfo(address(this), pid);
		if (tempAmount == 0) {
			bool done = votingContract.revokeVote(pid, amount);
			if (done == true) {
				success = true;
			} else {
				revert("Failed to call revokeVote().");
			}
		} else {
			success = true;
		}
	}

	function revokingDone(uint256 pid) public returns (bool) {
		uint256 lockingEndTime;
		(, , lockingEndTime) = votingContract.revokingInfo(address(this), pid);
		bool withdrawable = isWithdrawable(pid);
		if (lockingEndTime < block.timestamp && withdrawable == true) {
			return true;
		} else {
			return false;
		}
	}

	function isRevokingAllDone() public returns (bool allDone) {
		VotingData[] memory votingDatas = votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				bool done = revokingDone(votedData.pid);
				if (done == false) {
					allDone = false;
				}

				allDone = true;
			}
		}
	}

	function isWithdrawable(uint256 pid) public returns (bool) {
		return votingContract.isWithdrawable(address(this), pid);
	}

	function withdrawFromHeco(uint256 pid) public returns (uint256) {
		require(isWithdrawable(pid) == true);

		(uint256 tempAmount, , ) = votingContract.revokingInfo(address(this), pid);
		bool done = votingContract.withdraw(pid);
		if (done == true) {
			return tempAmount;
		} else {
			revert("Failed to withdraw from Heco voting.");
		}
	}

	function withdrawFromFilda() public returns (uint256) {
		uint256 savingBalance = loanContract.getSavingBalance(address(this));
		if (savingBalance > 0) {
			uint256 result = loanContract.redeemUnderlying(savingBalance);
			if (result > 0) {
				return result;
			} else {
				revert("Failed to withdraw from Filda");
			}
		} else {
			revert("No deposited HTT.");
		}
	}

	function repay() public payable {
		uint256 repayAmount = msg.value;
		require(repayAmount > 0);
		require(repayAmount <= loanContract.borrowBalanceCurrent(address(this)));
		require(msg.sender.balance >= repayAmount);

		bool done = loanContract.repayBehalf{ value: msg.value }(address(this));
		if (done == false) {
			revert("Failed to repay.");
		}
	}

	function revokeVotingAndRepay() public {
		require(isRevokingAllDone() == true, "Revoking vote is in progress...");
		uint256 amount = _withdrawAllFromHeco(false);

		require(address(this).balance >= amount);
		loanContract.repayBehalf{ value: amount }(address(this));
		_HTT.burn(amount);
	}

	function withdraw() public {
		require(isRevokingAllDone() == true, "Revoking vote is in progress...");
		uint256 amountHT = _withdrawAllFromHeco(false);
		uint256 amountHTT = withdrawFromFilda();
		_HTT.burn(amountHTT);
		payable(msg.sender).transfer(amountHT);
	}

	function liquidate() public payable {
		uint256 borrowBalanceCurrent = loanContract.borrowBalanceCurrent(address(this));
		uint256 savingBalance = loanContract.getSavingBalance(address(this));
		uint256 borrowed = borrowBalanceCurrent.mul(_denominator).div(savingBalance);
		require(borrowed > _borrowRate || borrowed > _liquidateRate);
		require(msg.sender != _owner);

		if (isRevokingAllDone() == false) {
			// Step 1: revoke all votes.
			_revokeAll(true);
			_firstLiquidater = msg.sender;
		} else {
			// Step 2: withdraw all.
			require(msg.value >= borrowBalanceCurrent);

			uint256 total = _withdrawAllFromHeco(true);
			loanContract.repayBehalf{ value: msg.value }(address(this));
			_secondLiquidater = msg.sender;
			_HTT.burn(savingBalance);

			uint256 bonus = total.mul(_bonusRateForLiquidater).div(_denominator).div(2);
			payable(_firstLiquidater).transfer(bonus);
			payable(_secondLiquidater).transfer(bonus);
		}
	}

	function withdrawQuickly() public {
		uint256 savingBalance = loanContract.getSavingBalance(address(this));
		uint256 borrowAmount = savingBalance.mul(_borrowQuicklyRate).div(_denominator);
		borrow(borrowAmount);
	}

	function _revokeAll(bool forLiquidation) private isLiquidating(forLiquidation) returns (bool allDone) {
		VotingData[] memory votingDatas = votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				bool success = revokeVote(votedData.pid, votedData.ballot);
				if (success == false) {
					revert("Failed to revoke one of votings");
				}
				allDone = true;
			}
		}
	}

	function _withdrawAllFromHeco(bool forLiquidation) private isLiquidating(forLiquidation) returns (uint256 totalAmount) {
		VotingData[] memory votingDatas = votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				withdrawFromHeco(votedData.pid);
				totalAmount += votedData.ballot;
			}
		}
	}
}
