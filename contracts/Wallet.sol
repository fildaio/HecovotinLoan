// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./Global.sol";
import "./GlobalConfig.sol";

contract Wallet is AccessControl, Global {
	using SafeMath for uint256;
	using Math for uint256;

	address private _owner;
	address private _admin;
	GlobalConfig private _config;
	address internal _firstLiquidater;
	address internal _secondLiquidater;
	uint256 internal _exchangeRate = 1e18;

	event VoteEvent(address voter, uint256 pid, uint256 amount);
	event BorrowEvent(address borrower, uint256 amount);
	event BurnHTTEvent(address voter, uint256 amount);
	event ClaimEvent(address caller, uint256 pid, uint256 amount);
	event WithdrawEvent(address voter, uint256 pid, uint256 amount);
	event QuickWithdrawEvent(address voter, uint256 amount);
	event RevokeEvent(address voter, uint256 pid, uint256 amount);
	event LiquidateEvent(address voter, uint256 amount);
	event RepayEvent(address voter, uint256 pid, uint256 amount);

	constructor(
		address owner,
		address admin,
		address config
	) {
		_owner = owner;
		_admin = admin;
		_config = GlobalConfig(config);
	}

	function allowance() public view returns (uint256) {
		return _config.HTT().allowance(_owner, address(_config.loanContract()));
	}

	function approve(uint256 amount) public returns (bool) {
		return _config.HTT().approve(address(_config.loanContract()), amount);
	}

	function vote(uint256 pid) public payable {
		_voteOn();
		_isOwner();

		uint256 amount = msg.value;
		uint256 minVoteAmount = _config.votingContract().VOTE_UNIT();

		require(amount >= minVoteAmount);

		address payable caller = payable(msg.sender);

		uint256 integerAmount = amount.div(minVoteAmount).mul(minVoteAmount);

		require(integerAmount > 0, "amount == 0");

		uint256 difference = amount.sub(integerAmount);
		if (difference > 0) {
			caller.transfer(difference);
		}

		require(_config.votingContract().vote{ value: integerAmount }(pid));

		uint256 oldBalance = _config.HTT().balanceOf(address(this));

		require(_config.HTT().mint(integerAmount), "mint error");

		uint256 newBalance = _config.HTT().balanceOf(address(this));

		require(newBalance.sub(oldBalance) == integerAmount);

		uint256 mintResult = _config.loanContract().mint(integerAmount);

		// require(mintResult.mul(_exchangeRateStored()).div(_config.decimals()) == integerAmount);
		require(mintResult == 0, "mint error");

		emit VoteEvent(caller, pid, integerAmount);
	}

	function getBorrowLimit() public returns (uint256) {
		return _config.loanContract().getSavingBalance(address(this)).mul(_config.borrowRate()).div(_config.denominator()).sub(_config.loanContract().borrowBalanceCurrent(address(this))).div(_config.decimals());
	}

	function borrow(uint256 borrowAmount) public {
		_isOwner();

		require(borrowAmount > 0 && borrowAmount <= getBorrowLimit());
		require(_config.loanContract().borrow(borrowAmount) == 0, "Failed to borrow");

		payable(msg.sender).transfer(borrowAmount);

		emit BorrowEvent(msg.sender, borrowAmount);
	}

	function claim(uint256 pid) public {
		_isOwner();

		require(_config.votingContract().pendingReward(pid) > 0, "No rewards to claim");

		uint256 oldBalance = address(this).balance;
		require(_config.votingContract().claimReward(pid));

		uint256 newBalance = address(this).balance;
		uint256 rewardToClaim = newBalance.sub(oldBalance);
		if (rewardToClaim > 0) {
			payable(msg.sender).transfer(rewardToClaim);

			emit ClaimEvent(msg.sender, pid, rewardToClaim);
		} else {
			revert(); //"Insufficient reward amount."
		}
	}

	function getPendingRewardFilda() public returns (uint256) {
		return _config.loanContract().getCompBalanceWithAccrued(address(this));
	}

	function claimFilda() public {
		_isOwner();
		require(_config.loanContract().claimComp(address(this)));
		uint256 fildaBalance = _config.filda().balanceOf(address(this));
		_config.filda().transfer(msg.sender, fildaBalance);
	}

	function revokeVote(uint256 pid, uint256 amount) public returns (bool success) {
		_isOwner();
		return _revokeVote(pid, amount);
	}

	function revokingInfo(uint256 pid)
		public
		view
		returns (
			uint256,
			uint8,
			uint256
		)
	{
		return _config.votingContract().revokingInfo(address(this), pid);
	}

	function isWithdrawable(uint256 pid) public view returns (bool) {
		return _config.votingContract().isWithdrawable(address(this), pid);
	}

	function withdrawVoting(uint256 pid) public returns (uint256 withdrawal) {
		_isOwner();
		_withdrawalOn();

		withdrawal = _withdrawOrRepay(pid, false);
		payable(msg.sender).transfer(address(this).balance);
		emit WithdrawEvent(msg.sender, pid, withdrawal);
	}

	function withdrawAndRepay(uint256 pid) public returns (uint256 withdrawal) {
		_isOwner();
		_withdrawalOn();

		withdrawal = _withdrawOrRepay(pid, true);
		uint256 balance = address(this).balance;
		if (balance > 0) {
			payable(msg.sender).transfer(balance);
		}
		emit WithdrawEvent(msg.sender, pid, withdrawal);
	}

	function withdrawAndRepayAll() public {
		_isOwner();
		_withdrawalOn();

		uint256 withdrawal = _withdrawAllVoting(true);
		payable(msg.sender).transfer(address(this).balance);
		emit WithdrawEvent(msg.sender, 99999, withdrawal);
	}

	function repay() public payable {
		uint256 repayAmount = msg.value;
		require(repayAmount > 0);
		require(repayAmount <= _config.loanContract().borrowBalanceCurrent(address(this)));
		require(msg.sender.balance >= repayAmount);

		require(_config.loanContract().repayBehalf{ value: msg.value }(address(this)));
	}

	function revokeAllVoting() public {
		_isOwner();
		_revokeAll();
	}

	function withdrawAllVoting() public returns (uint256 totalAmount) {
		_isOwner();
		_withdrawalOn();

		return _withdrawAllVoting(false);
	}

	function liquidate() public payable {
		uint256 borrowBalanceCurrentAmount = _config.loanContract().borrowBalanceCurrent(address(this));
		uint256 savingBalance = _config.loanContract().getSavingBalance(address(this));
		uint256 borrowed = borrowBalanceCurrentAmount.mul(_config.denominator()).div(savingBalance);
		require(borrowed > _config.liquidateRate());

		if (_haveAllVotesBeenRevoked() == false) {
			// Step 1: revoke all votes.
			_revokeAll();
			_firstLiquidater = msg.sender;
		} else {
			// Step 2: withdraw all.
			require(msg.value >= borrowBalanceCurrentAmount);

			uint256 total = _withdrawAllVoting(true);

			_secondLiquidater = msg.sender;

			uint256 bonus = total.mul(_config.bonusRateForLiquidater()).div(_config.denominator()).div(2);
			if (_firstLiquidater != _owner) payable(_firstLiquidater).transfer(bonus);
			if (_secondLiquidater != _owner) payable(_secondLiquidater).transfer(bonus);

			payable(_admin).transfer(address(this).balance);

			emit LiquidateEvent(address(this), total);
		}
	}

	function quickWithdrawal() public {
		_withdrawalOn();
		uint256 savingBalance = _config.loanContract().getSavingBalance(address(this));
		uint256 borrowAmount = savingBalance.mul(_config.borrowQuicklyRate()).div(_config.denominator()).sub(_config.loanContract().borrowBalanceCurrent(address(this)).div(_config.decimals()));
		borrow(borrowAmount);
		liquidate();

		emit QuickWithdrawEvent(msg.sender, borrowAmount);
	}

	// 检查已发起的撤回投票是否完成。
	// 不存在已发起的撤回投票，以及有未完成的撤回投票，都会返回false。
	function _haveAllVotesBeenRevoked() private returns (bool allDone) {
		VotingData[] memory votingDatas = _config.votingContract().getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				(uint256 amount, , uint256 lockingEndTime) = revokingInfo(votedData.pid);

				// TODO: 确认一下，是否只需要读取投票中的HT数量即可，不必同时判断这三个条件？
				if (lockingEndTime > block.timestamp && isWithdrawable(votedData.pid) && amount < votedData.ballot) {
					allDone = false;
				}

				allDone = true;
			}
		}
	}

	function _withdrawOrRepay(uint256 pid, bool toRepay) private returns (uint256 withdrawal) {
		require(isWithdrawable(pid) == true);

		uint256 oldBalance = address(this).balance;
		require(_config.votingContract().withdraw(pid));
		uint256 newBalance = address(this).balance;
		withdrawal = newBalance.sub(oldBalance);

		if (toRepay) {
			uint256 borrowed = _config.loanContract().borrowBalanceCurrent(msg.sender);
			uint256 repayAmount = borrowed.min(address(this).balance);

			if (repayAmount > 0) {
				require(_config.loanContract().repayBehalf{ value: repayAmount }(address(this)));
				emit RepayEvent(msg.sender, pid, repayAmount);
			}
		}

		oldBalance = _config.HTT().balanceOf(address(this));
		_config.loanContract().redeemUnderlying(withdrawal);
		newBalance = _config.HTT().balanceOf(address(this));

		require(newBalance.sub(oldBalance) == withdrawal, "Incorrect withdrawal amount");
		require(_config.HTT().burn(withdrawal), "burn error");

		emit BurnHTTEvent(msg.sender, withdrawal);
	}

	function _revokeAll() private returns (bool allDone) {
		VotingData[] memory votingDatas = _config.votingContract().getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				bool success = _revokeVote(votedData.pid, votedData.ballot);
				if (success == false) {
					revert(); //"Failed to revoke one of votings"
				}
				allDone = true;
			}
		}
	}

	function _withdrawAllVoting(bool toRepay) private returns (uint256 totalAmount) {
		VotingData[] memory votingDatas = _config.votingContract().getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				_withdrawOrRepay(votedData.pid, toRepay);
				totalAmount += votedData.ballot;
			}
		}
	}

	function _exchangeRateStored() private returns (uint256) {
		uint256 result = _config.loanContract().exchangeRateCurrent();
		if (result > 0) {
			_exchangeRate = result;
		}
		return _exchangeRate;
	}

	function _voteOn() private view {
		require(_config.voteOn() == true, "Vote disabled.");
	}

	function _withdrawalOn() private view {
		require(_config.withdrawalOn() == true, "Withdrawal disabled");
	}

	function _isOwner() private view {
		require(msg.sender == _owner);
	}

	function _revokeVote(uint256 pid, uint256 amount) public returns (bool success) {
		require(_config.votingContract().revokeVote(pid, amount));
		emit RevokeEvent(msg.sender, pid, amount);
		return true;
	}
}
