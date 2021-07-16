// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface Global {
	struct VotingData {
		address validator; // 验证人节点地址
		uint256 pid; // 节点投票质押池ID
		uint256 validatorBallot; // 验证人票数
		uint256 feeShares; // 节点分成份额
		uint256 ballot; // 我的投票数
		uint256 pendingReward; // 可领取奖励
		uint256 revokingBallot; // 正在撤回的投票数
		uint256 revokeLockingEndTime; // 撤回投票的锁定时间
	}
}
