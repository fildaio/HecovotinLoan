// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface WalletFactoryInterface {
	function getOwner(address walletAddress) external view returns (address);
}
