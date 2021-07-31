// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface CTokenInterface {
	function borrowIndex() external view returns (uint256);

	function borrowBalanceStored(address account) external view returns (uint256);

	function borrowBalanceCurrent(address account) external returns (uint256);

	function balanceOfUnderlying(address owner) external returns (uint256);

	function exchangeRateCurrent() external returns (uint256);
}

interface ComptrollerInterface {
	function claimComp(address) external;

	function claimComp(address user, CTokenInterface[] memory tokens) external;

	function compAccrued(address) external view returns (uint256);

	function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);
}
