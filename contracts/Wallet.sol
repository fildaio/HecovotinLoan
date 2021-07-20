// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./VotingStrategy.sol";
import "./LoanStrategy.sol";
import "./HTTokenInterface.sol";
import "./Global.sol";

contract Wallet is AccessControl, Global {
	using SafeMath for uint256;
	using Math for uint256;

	struct RedeemingState {
		uint256 blockNumber;
		uint256 amount;
	}

	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
	bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

	address private _owner;
	uint256 private _decimals = 1e18;
	uint256 private _minVoteAmount = 1e18;
	uint256 private _denominator = 10000;
	uint256 private _borrowRate = 8000;
	uint256 private _borrowQuicklyRate = 9700;
	uint256 private _liquidateRate = 9000;
	uint256 private _bonusRateForLiquidater = 300;
	address private _firstLiquidater;
	address private _secondLiquidater;
	address private _admin;
	uint256 private _exchangeRate = 1e18;
	HTTokenInterface private _HTT;
	VotingStrategy private _votingContract;
	LoanStrategy private _loanContract;

	event VoteEvent(address voter, uint256 pid, uint256 amount);
	event BurnHTTEvent(address voter, uint256 amount);
	event ClaimEvent(address caller, uint256 pid, uint256 amount);
	event WithdrawEvent(address voter, uint256 pid, uint256 amount);
	event QuickWithdrawEvent(address voter, uint256 amount);
	event RevokeEvent(address voter, uint256 pid, uint256 amount);
	event LiquidateEvent(address voter, uint256 amount);
	event RepayEvent(address voter, uint256 pid, uint256 amount);

	modifier byAdmin() {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
		_;
	}

	modifier byConfigRole() {
		require(hasRole(CONFIG_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin or the configuration roles..");
		_;
	}

	constructor(address owner, address admin) {
		_setupRole(ADMIN_ROLE, msg.sender);
		_setupRole(CONFIG_ROLE, msg.sender);

		_owner = owner;
		_admin = admin;
	}

	function setConfigRole(address configRoleAddress) public byAdmin() {
		_setupRole(CONFIG_ROLE, configRoleAddress);
	}

	function setHTToken(address contractAddress) public byConfigRole() {
		_HTT = HTTokenInterface(contractAddress);
	}

	function setVotingContract(address contractAddress) public byConfigRole() {
		_votingContract = VotingStrategy(contractAddress);
	}

	function setLoanContract(address contractAddress) public byConfigRole() {
		_loanContract = LoanStrategy(contractAddress);
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

		require(_votingContract.vote{ value: integerAmount }(pid));

		uint256 oldBalance = _HTT.balance(address(this));
		bool mintHTTResult = _HTT.mint(integerAmount);
		if (mintHTTResult == false) {
			revert(); //"Failed to mint HTT."
		}

		uint256 newBalance = _HTT.balance(address(this));

		require(newBalance.sub(oldBalance) == integerAmount);

		uint256 mintResult = _loanContract.mint(integerAmount);

		require(mintResult.mul(_exchangeRateStored()).div(_decimals) == integerAmount);

		emit VoteEvent(caller, pid, integerAmount);
	}

	function getBorrowLimit() public returns (uint256) {
		return _loanContract.getSavingBalance(address(this)).mul(_borrowRate).div(_denominator);
	}

	function getLiquidateLimit() public returns (uint256) {
		return _loanContract.getSavingBalance(address(this)).mul(_liquidateRate).div(_denominator);
	}

	function borrow(uint256 borrowAmount) public {
		require(borrowAmount > 0 && borrowAmount <= getLiquidateLimit().sub(_loanContract.borrowBalanceCurrent(address(this))));

		uint256 borrowed = _loanContract.borrow(borrowAmount);

		require(borrowed > 0);

		payable(msg.sender).transfer(borrowed);
	}

	function claim(uint256 pid) public {
		require(_votingContract.pendingReward(pid) > 0, "No rewards to claim.");

		uint256 oldBalance = address(this).balance;
		require(_votingContract.claimReward(pid));

		uint256 newBalance = address(this).balance;
		uint256 rewardToClaim = newBalance.sub(oldBalance);
		if (rewardToClaim > 0) {
			payable(msg.sender).transfer(rewardToClaim);

			emit ClaimEvent(msg.sender, pid, rewardToClaim);
		} else {
			revert(); //"Insufficient reward amount."
		}
	}

	function revokeVote(uint256 pid, uint256 amount) public returns (bool success) {
		require(_votingContract.revokeVote(pid, amount));
		emit RevokeEvent(msg.sender, pid, amount);
		return true;
	}

	function revokingInfo(uint256 pid)
		public
		returns (
			uint256,
			uint8,
			uint256
		)
	{
		return _votingContract.revokingInfo(address(this), pid);
	}

	function isWithdrawable(uint256 pid) public returns (bool) {
		return _votingContract.isWithdrawable(address(this), pid);
	}

	function withdrawVoting(uint256 pid) public returns (uint256 withdrawal) {
		require(msg.sender == _owner);
		withdrawal = _withdrawOrRepay(pid, false);
		payable(msg.sender).transfer(address(this).balance);
		emit WithdrawEvent(msg.sender, pid, withdrawal);
	}

	function withdrawAndRepay(uint256 pid) public returns (uint256 withdrawal) {
		require(msg.sender == _owner);
		withdrawal = _withdrawOrRepay(pid, true);
		payable(msg.sender).transfer(address(this).balance);
		emit WithdrawEvent(msg.sender, pid, withdrawal);
	}

	function withdrawAndRepayAll() public {
		require(msg.sender == _owner);
		uint256 withdrawal = _withdrawAllVoting(true);
		payable(msg.sender).transfer(address(this).balance);
		emit WithdrawEvent(msg.sender, 99999, withdrawal);
	}

	function repay() public payable {
		uint256 repayAmount = msg.value;
		require(repayAmount > 0);
		require(repayAmount <= _loanContract.borrowBalanceCurrent(address(this)));
		require(msg.sender.balance >= repayAmount);

		require(_loanContract.repayBehalf{ value: msg.value }(address(this)));
	}

	function revokeAllVoting() public {
		require(msg.sender == _owner);
		_revokeAll();
	}

	function withdrawAllVoting() public returns (uint256 totalAmount) {
		require(msg.sender == _owner);
		return _withdrawAllVoting(false);
	}

	function liquidate() public payable {
		uint256 borrowBalanceCurrentAmount = _loanContract.borrowBalanceCurrent(address(this));
		uint256 savingBalance = _loanContract.getSavingBalance(address(this));
		uint256 borrowed = borrowBalanceCurrentAmount.mul(_denominator).div(savingBalance);
		require(borrowed > _liquidateRate);

		if (_haveAllVotesBeenRevoked() == false) {
			// Step 1: revoke all votes.
			_revokeAll();
			_firstLiquidater = msg.sender;
		} else {
			// Step 2: withdraw all.
			require(msg.value >= borrowBalanceCurrentAmount);

			uint256 total = _withdrawAllVoting(true);

			_secondLiquidater = msg.sender;

			uint256 bonus = total.mul(_bonusRateForLiquidater).div(_denominator).div(2);
			if (_firstLiquidater != _owner) payable(_firstLiquidater).transfer(bonus);
			if (_secondLiquidater != _owner) payable(_secondLiquidater).transfer(bonus);

			payable(_admin).transfer(address(this).balance);

			emit LiquidateEvent(address(this), total);
		}
	}

	function quickWithdrawal() public {
		uint256 savingBalance = _loanContract.getSavingBalance(address(this));
		uint256 borrowAmount = savingBalance.mul(_borrowQuicklyRate).div(_denominator).sub(_loanContract.borrowBalanceCurrent(address(this)));
		borrow(borrowAmount);
		liquidate();
		emit QuickWithdrawEvent(msg.sender, borrowAmount);
	}

	// 检查已发起的撤回投票是否完成。
	// 不存在已发起的撤回投票，以及有未完成的撤回投票，都会返回false。
	function _haveAllVotesBeenRevoked() private returns (bool allDone) {
		VotingData[] memory votingDatas = _votingContract.getUserVotingSummary(address(this));
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
		require(_votingContract.withdraw(pid));
		uint256 newBalance = address(this).balance;
		withdrawal = newBalance.sub(oldBalance);

		uint256 result;
		if (toRepay) {
			uint256 borrowed = _loanContract.borrowBalanceCurrent(msg.sender);
			uint256 repayAmount = borrowed.min(address(this).balance);

			require(_loanContract.repayBehalf{ value: repayAmount }(address(this)));

			emit RepayEvent(msg.sender, pid, repayAmount);
		}

		result = _loanContract.redeemUnderlying(withdrawal);

		require(result == withdrawal);

		_HTT.burn(result);

		emit BurnHTTEvent(msg.sender, result);
	}

	// 撤回全部投票的全部量，只供清算时内部调用。
	function _revokeAll() private returns (bool allDone) {
		VotingData[] memory votingDatas = _votingContract.getUserVotingSummary(address(this));
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

	function _withdrawAllVoting(bool toRepay) private returns (uint256 totalAmount) {
		VotingData[] memory votingDatas = _votingContract.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				_withdrawOrRepay(votedData.pid, toRepay);
				totalAmount += votedData.ballot;
			}
		}
	}

	function _exchangeRateStored() private view returns (uint256) {
		return _exchangeRate;
	}
}
