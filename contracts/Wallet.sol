// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./VotingStrategy.sol";
import "./LoanStrategy.sol";
import "./HTTokenInterface.sol";

contract Wallet is AccessControl {
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
	uint256 private _borrowRate = 80;
	uint256 private _emergencyBorrowRate = 98;
	uint256 private _liquidateRate = 90;
	uint256 private _bonusRateForLiquidater = 3;
	address private _firstLiquidater;
	address private _secondLiquidater;
	uint256 private _loan;
	uint256 private _totalVoted;
	mapping(uint256 => uint256) private _voted;
	address payable private _deployedVoteContract = payable(address(0x123));
	address payable private _deployedLoanContract = payable(address(0x123));
	HTTokenInterface private _HTT = HTTokenInterface(address(0x123));

	// Events
	event voteEvent(address voter, uint256 pid, uint256 amount);

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
		require(amount > _minVoteAmount);

		address payable caller = payable(msg.sender);

		uint256 integerAmount = amount.div(_minVoteAmount).mul(_minVoteAmount);
		uint256 difference = amount.sub(integerAmount);
		if (difference > 0) {
			caller.transfer(difference);
		}

		bool done = votingContract.vote{ value: integerAmount }(pid);
		if (done == true) {
			uint256 oldBalance = _HTT.balance(address(this));

			_voted[pid] += integerAmount;
			_totalVoted += integerAmount;

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
		return loanContract.getSavingBalance(address(this)).mul(_borrowRate).div(100);
	}

	function borrow(uint256 borrowAmount) public {
		require(borrowAmount > 0);
		require(borrowAmount <= getBorrowLimit());

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

	function revokeVote(uint256 pid, uint256 amount) public {
		uint256 tempAmount;
		(tempAmount, , ) = votingContract.revokingInfo(address(this), pid);
		require(tempAmount == 0);

		require(_voted[pid] >= amount);
		votingContract.revokeVote(pid, amount);
	}

	function isWithdrawable(uint256 pid) public returns (bool) {
		return votingContract.isWithdrawable(address(this), pid);
	}

	function withdrawFromHeco(uint256 pid) public returns (uint256) {
		require(isWithdrawable(pid) == true);

		(uint256 tempAmount, , ) = votingContract.revokingInfo(address(this), pid);
		bool done = votingContract.withdraw(pid);
		if (done == true) {
			_voted[pid] -= tempAmount;
			_totalVoted -= tempAmount;
			return tempAmount;
		} else {
			revert("Failed to withdraw from Heco voting.");
		}
	}

	function rePay() public payable {
		uint256 repayAmount = msg.value;
		require(repayAmount > 0);
		require(repayAmount <= loanContract.borrowBalanceCurrent(address(this)));
		require(msg.sender.balance >= repayAmount);

		bool done = loanContract.repayBehalf{ value: msg.value }(address(this));
		if (done == false) {
			revert("Failed to repay.");
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

	function withdraw() public {
		uint256 withdrawal = withdrawFromFilda();
		_HTT.burn(withdrawal);

		// uint256 loanBalance = loanContract.borrowBalanceCurrent(address(this));
		// if (loanBalance > 0) {
		// 	uint256 result = loanContract.repayBorrow(address(this), loanBalance);
		// 	if()
		// } else {
		// 	revert("No loans.");
		// }
		// // setp 1.
		// uint256 tempAmount = votingContract.withdraw(pid);
		// _voted[pid] -= tempAmount;
		// _totalVoted -= tempAmount;
		// // setp 2.
		// payable(msg.sender).transfer(tempAmount);
		// // _HTT.burn(amount, caller);
		// return tempAmount;
	}

	function redeemAndRePay(uint256 pid) public {
		require(_loan <= _voted[pid].mul(_borrowRate).div(100));
		require(isWithdrawable(pid) == true);

		uint256 lockingEndTime;
		(, , lockingEndTime) = votingContract.revokingInfo(address(this), pid);
		require(lockingEndTime < block.timestamp);

		// 需要amount,
		uint256 amount = withdrawFromHeco(pid);
		_HTT.burn(amount);
		votingContract.withdraw(pid);
		// loanContract.repayBorrow(payable(msg.sender), amount);
		// 下面的调用似乎的错的。
		loanContract.repayBehalf(msg.sender);
		// 提取htt
		// htt.burn()
	}

	// 改名revokeALl()
	function beginLiquidate() public {
		//从filda读取借款使用率。and
		// 判断msg.sender是不是本人。
		uint256 total = votingContract.getPoolLength();
		for (uint256 i = 0; i < total; i++) {
			if (_voted[i] > 0) {
				revokeVote(i, _voted[i]);
			}
		}

		//从filda读取借款使用率。不超为0。
		_firstLiquidater = msg.sender;
	}

	function liquidate() public {
		//从filda读取借款使用率。
		// require(isLiquidating == true);

		uint256 total = votingContract.getPoolLength();
		for (uint256 i = 0; i < total; i++) {
			if (_voted[i] > 0) {
				withdrawFromHeco(i);
				_voted[i] = 0;
			}
		}

		_secondLiquidater = msg.sender;

		// loanContract.repayBorrow(payable(_owner), loanContract.borrowBalanceCurrent(msg.sender));
		// 下面的调用似乎是错的。
		loanContract.repayBehalf(_owner);

		_HTT.burn(_totalVoted);

		uint256 bonus = _totalVoted.mul(_bonusRateForLiquidater).div(100).div(2);
		payable(_firstLiquidater).transfer(bonus);
		payable(_secondLiquidater).transfer(bonus);

		_totalVoted = 0;
		_loan = 0;
	}

	function emergencyWithdraw(uint256 borrowAmount) public {
		// 参数不必要。
		require(borrowAmount > 0);
		require(borrowAmount <= _totalVoted.mul(_emergencyBorrowRate).div(100));

		//根据filda的数据来算。
		loanContract.borrow(borrowAmount);
		payable(msg.sender).transfer(borrowAmount);

		//revokeAll()
		//清算开始。
	}
}
