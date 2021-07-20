// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Wallet.sol";

contract WalletFactory is AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	mapping(address => Wallet) wallets;
	mapping(address => address) users;

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function makeWallet() public {
		require(wallets[msg.sender].isExist() == false);
		Wallet wallet = new Wallet(msg.sender, msg.sender);
		address walletAddress = address(wallet);
		wallets[msg.sender] = wallet;
		users[walletAddress] = msg.sender;
	}

	function getWallet(address owner) public view returns (address) {
		return address(wallets[owner]);
	}

	function getOwner(address walletAddress) public view returns (address) {
		return users[walletAddress];
	}
}
