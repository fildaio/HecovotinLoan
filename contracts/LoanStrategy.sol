// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Global.sol";

interface LoanStrategy is Global {
	function repayBehalf(address who) external payable returns (bool);

	function borrowBalanceCurrent(address user) external returns (uint256);

	function getCompBalanceWithAccrued(address owner) external returns (uint256 balance, uint256 allocated);

	function claimComp(address owner) external returns (bool);

	function exchangeRateCurrent() external returns (uint256);

	function enterMarkets(address depositToken) external returns (uint256[] memory);
}
