// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface VotingStrategy {
	function getPoolLength() external returns (uint256);

	function vote(uint256 pid) external payable returns (bool);

	function revokeVote(uint256 pid, uint256 amount) external;

	function isWithdrawable(address user, uint256 pid) external returns (bool);

	function withdraw(uint256 pid) external returns (uint256);

	function pendingReward(uint256 pid) external returns (uint256);

	function claimReward(uint256 pid) external returns (bool);

	function reinvest() external payable;

	function userInfo(address userAddress) external returns (uint256 votedHT, uint256 ownedHTT);

	function revokingInfo(address user, uint256 pid)
		external
		returns (
			uint256,
			uint8,
			uint256
		);
}
