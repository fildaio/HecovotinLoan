// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Global.sol";

interface LoanStrategy is Global {
	function borrow(uint256 borrowAmount) external payable returns (uint256);

	function mint(uint256 mintAmount) external returns (uint256);

	function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

	function repayBehalf(address who) external payable returns (bool);

	function borrowBalanceCurrent(address user) external returns (uint256);

	function getSavingBalance(address owner) external returns (uint256);

	function getCompBalanceWithAccrued(address owner) external returns (uint256);

	function claimComp(address owner) external returns (bool);

	function exchangeRateCurrent() external returns (uint256);
}
