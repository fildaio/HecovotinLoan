// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface LoanStrategy {
	function borrowBalanceCurrent(address user) external returns (uint256);

	function getCompBalanceWithAccrued(address owner) external returns (uint256 balance, uint256 allocated);

	function claimComp(address owner) external returns (bool);

	function exchangeRateCurrent() external returns (uint256);
}
