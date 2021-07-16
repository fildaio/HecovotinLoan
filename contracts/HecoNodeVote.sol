// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./VotingStrategy.sol";
import "./HTTokenInterface.sol";

interface HecoNodeVoteInterface {
	function getPoolLength() external returns (uint256);

	function vote(uint256 pid) external payable;

	function revokeVote(uint256 pid, uint256 amount) external;

	function withdraw(uint256 pid) external returns (uint256);

	function claimReward(uint256 pid) external;

	function pendingReward(uint256 pid, address user) external returns (uint256);

	function _isWithdrawable(address _user, uint256 _pid) external returns (bool);

	function getUserVotingSummary(address _user)
		external
		returns (
			address,
			uint256,
			uint256,
			uint256,
			uint256,
			uint256,
			uint256,
			uint256
		);

	function revokingInfo(address _user, uint256 _pid)
		external
		returns (
			uint256,
			uint8,
			uint256
		);
}

contract HecoNodeVote is VotingStrategy {
	HTTokenInterface public HTT = HTTokenInterface(address(0x123));
	HecoNodeVoteInterface public voting = HecoNodeVoteInterface(0x80d1769ac6fee59BE5AAC1952a90270bbd2Ceb2F);

	mapping(address => uint256) voted;

	function getPoolLength() external override returns (uint256) {
		return voting.getPoolLength();
	}

	function vote(uint256 pid) external payable override returns (bool) {
		try voting.vote{ value: msg.value }(pid) {
			return true;
		} catch {
			return false;
		}
	}

	function revokeVote(uint256 pid, uint256 amount) external override {
		voting.revokeVote(pid, amount);
	}

	function revokingInfo(address user, uint256 pid)
		external
		override
		returns (
			uint256,
			uint8,
			uint256
		)
	{
		return voting.revokingInfo(user, pid);
	}

	function isWithdrawable(address user, uint256 pid) external override returns (bool) {
		return voting._isWithdrawable(user, pid);
	}

	function withdraw(uint256 pid) external override returns (bool) {
		try voting.withdraw(pid) {
			return true;
		} catch {
			return false;
		}
	}

	function pendingReward(uint256 pid) external override returns (uint256) {
		return voting.pendingReward(pid, msg.sender);
	}

	function claimReward(uint256 pid) external override returns (bool) {
		try voting.claimReward(pid) {
			return true;
		} catch {
			return false;
		}
	}

	function reinvest() external payable override {}

	function userInfo(address userAddress) external view override returns (uint256 votedHT, uint256 ownedHTT) {
		votedHT = voted[userAddress];
		ownedHTT = HTT.balance(userAddress);
	}
}
