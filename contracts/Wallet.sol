// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Global.sol";
import "./GlobalConfig.sol";
import "./HTTokenInterface.sol";
import "./LoanStrategy.sol";
import "./ComptrollerInterface.sol";

interface HecoNodeVoteInterface is Global {
	function vote(uint256 _pid) external payable;

	function revokeVote(uint256 _pid, uint256 _amount) external;

	function withdraw(uint256 _pid) external;

	function claimReward(uint256 _pid) external;

	function _isWithdrawable(address _user, uint256 _pid) external view returns (bool);

	function pendingReward(uint256 _pid, address _user) external view returns (uint256);

	function getUserVotingSummary(address _user) external view returns (VotingData[] memory);

	function revokingInfo(address _user, uint256 _pid)
		external
		view
		returns (
			uint256,
			uint8,
			uint256
		);

	function VOTE_UNIT() external view returns (uint256);
}

interface BankInterface {
	function mint(uint256 mintAmount) external returns (uint256);

	function borrow(uint256 borrowAmount) external returns (uint256);

	function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

	function repayBorrow(uint256 repayAmount) external returns (uint256);

	function balanceOf(address owner) external view returns (uint256);
}

contract Wallet is AccessControl, Global {
	using SafeMath for uint256;
	using Math for uint256;

	address private _owner;
	address private _admin;
	address internal _firstLiquidater;
	address internal _secondLiquidater;
	uint256 internal _exchangeRate = 1e18;
	GlobalConfig private _config;
	HecoNodeVoteInterface private _voting;
	HTTokenInterface private _HTT;
	LoanStrategy private _loanContract;
	BankInterface private _borrowContract;
	BankInterface private _depositContract;
	ComptrollerInterface private _comptrollerContract;

	event VoteEvent(address voter, uint256 pid, uint256 amount);
	event BorrowEvent(address borrower, uint256 amount);
	event BurnHTTEvent(address voter, uint256 amount);
	event ClaimEvent(address caller, uint256 pid, uint256 amount);
	event WithdrawEvent(address voter, uint256 pid, uint256 amount);
	event QuickWithdrawEvent(address voter, uint256 amount);
	event RevokeEvent(address voter, uint256 pid, uint256 amount);
	event LiquidateEvent(address voter, uint256 amount);
	event RepayEvent(address voter, uint256 pid, uint256 amount);
	event EnterMarkets(address caller, address market);

	constructor(
		address owner,
		address admin,
		address config
	) {
		_owner = owner;
		_admin = admin;
		_config = GlobalConfig(config);
		_voting = HecoNodeVoteInterface(_config.votingContract());
		_HTT = HTTokenInterface(_config.HTT());
		_loanContract = LoanStrategy(_config.loanContract());
		_depositContract = BankInterface(_config.depositContract());
		_borrowContract = BankInterface(_config.borrowContract());
		_comptrollerContract = ComptrollerInterface(_config.comptrollerContract());
	}

	receive() external payable {}

	function allowance() public view returns (uint256) {
		return _HTT.allowance(_owner, _config.loanContract());
	}

	function approve(uint256 amount) public returns (bool) {
		return _HTT.approve(_config.depositContract(), amount);
	}

	function VOTE_UNIT() public view returns (uint256) {
		return _voting.VOTE_UNIT();
	}

	function vote(uint256 pid) public payable {
		_voteOn();
		_isOwner();

		uint256 amount = msg.value;
		uint256 minVoteAmount = VOTE_UNIT();

		require(amount >= minVoteAmount, "amount < min");

		address payable caller = payable(msg.sender);

		uint256 integerAmount = amount.div(minVoteAmount).mul(minVoteAmount);

		require(integerAmount > 0, "amount == 0");

		uint256 difference = amount.sub(integerAmount);
		if (difference > 0) {
			caller.transfer(difference);
		}

		try _voting.vote{ value: integerAmount }(pid) {
			depositHTT(integerAmount);
			emit VoteEvent(caller, pid, integerAmount);
		} catch {
			revert("vote error");
		}
	}

	function enterMarkets(address[] memory args) public returns (uint256[] memory result) {
		result = _comptrollerContract.enterMarkets(args);
		emit EnterMarkets(address(this), _config.depositContract());
	}

	function checkMembership() public view returns (bool) {
		return _comptrollerContract.checkMembership(address(this), CTokenInterface(_config.depositContract()));
	}

	function depositHTT(uint256 integerAmount) public {
		_isOwner();

		uint256 oldBalance = _HTT.balanceOf(address(this));

		require(_HTT.mint(integerAmount), "mint error");

		uint256 newBalance = _HTT.balanceOf(address(this));

		require(newBalance.sub(oldBalance) == integerAmount, "the minted HTT amount wrong");
		require(_depositContract.mint(integerAmount) == 0, "deposit error");
	}

	function getUserVotingSummary() external view returns (VotingData[] memory) {
		return _voting.getUserVotingSummary(address(this));
	}

	function getBorrowLimit() public returns (uint256) {
		return _depositContract.balanceOf(address(this)).mul(_config.borrowRate()).div(_config.denominator()).sub(_loanContract.borrowBalanceCurrent(address(this)));
	}

	function borrow(uint256 borrowAmount) public {
		_isOwner();

		require(borrowAmount > 0 && borrowAmount <= getBorrowLimit(), "amount > limit");
		require(_borrowContract.borrow(borrowAmount) == 0, "Failed to borrow");

		payable(msg.sender).transfer(borrowAmount);
		emit BorrowEvent(msg.sender, borrowAmount);
	}

	function getBalance() public view returns (uint256) {
		return address(this).balance;
	}

	function pendingReward(uint256 pid) public view returns (uint256) {
		return _voting.pendingReward(pid, address(this));
	}

	function claim(uint256 pid) public {
		_isOwner();

		require(_voting.pendingReward(pid, address(this)) > 0, "No rewards to claim");

		uint256 oldBalance = address(this).balance;

		try _voting.claimReward(pid) {
			uint256 newBalance = address(this).balance;
			uint256 rewardToClaim = newBalance.sub(oldBalance);
			if (rewardToClaim > 0) {
				payable(msg.sender).transfer(rewardToClaim);

				emit ClaimEvent(msg.sender, pid, rewardToClaim);
			} else {
				revert("Insufficient reward");
			}
		} catch {
			revert("claim HT error");
		}
	}

	function getPendingRewardFilda() public returns (uint256 balance, uint256 allocated) {
		return _loanContract.getCompBalanceWithAccrued(address(this));
	}

	function claimFilda() public {
		_isOwner();
		require(_loanContract.claimComp(address(this)), "claim filda error");
		uint256 fildaBalance = _config.filda().balanceOf(address(this));
		if (fildaBalance > 0) {
			_config.filda().transfer(msg.sender, fildaBalance);
		}
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
		return _voting.revokingInfo(address(this), pid);
	}

	function isWithdrawable(uint256 pid) public view returns (bool) {
		return _voting._isWithdrawable(address(this), pid);
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
		require(repayAmount > 0, "amount == 0");
		require(repayAmount <= _loanContract.borrowBalanceCurrent(address(this)), "amount <= borrowBalance");
		require(msg.sender.balance >= repayAmount, "insufficient balance");
		require(_loanContract.repayBehalf{ value: msg.value }(address(this)), "repay error");
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
		uint256 borrowBalanceCurrentAmount = _loanContract.borrowBalanceCurrent(address(this));
		uint256 savingBalance = _depositContract.balanceOf(address(this));
		uint256 borrowed = borrowBalanceCurrentAmount.mul(_config.denominator()).div(savingBalance);
		require(borrowed > _config.liquidateRate(), "borrowed < liquidete limit");

		if (_haveAllVotesBeenRevoked() == false) {
			// Step 1: revoke all votes.
			_revokeAll();
			_firstLiquidater = msg.sender;
		} else {
			// Step 2: withdraw all.
			require(msg.value >= borrowBalanceCurrentAmount, "insufficient amount");

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
		uint256 savingBalance = _depositContract.balanceOf(address(this));
		uint256 borrowAmount = savingBalance.mul(_config.borrowQuicklyRate()).div(_config.denominator()).sub(_loanContract.borrowBalanceCurrent(address(this)).div(_config.decimals()));
		borrow(borrowAmount);
		liquidate();

		emit QuickWithdrawEvent(msg.sender, borrowAmount);
	}

	// 检查已发起的撤回投票是否完成。
	// 不存在已发起的撤回投票，以及有未完成的撤回投票，都会返回false。
	function _haveAllVotesBeenRevoked() private view returns (bool allDone) {
		VotingData[] memory votingDatas = _voting.getUserVotingSummary(address(this));
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
		require(isWithdrawable(pid) == true, "pool cannot be withdraw");

		uint256 oldBalance = address(this).balance;

		try _voting.withdraw(pid) {
			uint256 newBalance = address(this).balance;
			withdrawal = newBalance.sub(oldBalance);

			if (toRepay) {
				uint256 borrowed = _loanContract.borrowBalanceCurrent(msg.sender);
				uint256 repayAmount = borrowed.min(address(this).balance);

				if (repayAmount > 0) {
					// require(_borrowContract.repayBorrow(repayAmount) == 0, "repay error");
					require(_loanContract.repayBehalf{ value: repayAmount }(address(this)), "repay error");
					emit RepayEvent(msg.sender, pid, repayAmount);
				}
			}

			oldBalance = _HTT.balanceOf(address(this));
			_depositContract.redeemUnderlying(withdrawal);
			newBalance = _HTT.balanceOf(address(this));

			require(newBalance.sub(oldBalance) == withdrawal, "Incorrect withdrawal amount");
			require(_HTT.burn(withdrawal), "burn error");

			emit BurnHTTEvent(msg.sender, withdrawal);
		} catch {
			revert("withdraw error");
		}
	}

	function _revokeAll() private returns (bool allDone) {
		VotingData[] memory votingDatas = _voting.getUserVotingSummary(address(this));
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
		VotingData[] memory votingDatas = _voting.getUserVotingSummary(address(this));
		if (votingDatas.length > 0) {
			for (uint256 i = 0; i < votingDatas.length; i++) {
				VotingData memory votedData = votingDatas[i];
				_withdrawOrRepay(votedData.pid, toRepay);
				totalAmount += votedData.ballot;
			}
		}
	}

	function _exchangeRateStored() private returns (uint256) {
		uint256 result = _loanContract.exchangeRateCurrent();
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
		require(msg.sender == _owner, "not owner");
	}

	function _revokeVote(uint256 pid, uint256 amount) private returns (bool success) {
		try _voting.revokeVote(pid, amount) {
			emit RevokeEvent(msg.sender, pid, amount);
			return true;
		} catch {
			revert("revoke error");
		}
	}
}
