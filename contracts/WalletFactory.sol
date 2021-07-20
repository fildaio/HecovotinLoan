// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Wallet.sol";

contract WalletFactory is AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	mapping(address => address) private _wallets;
	mapping(address => address) private _users;

	event MakeWalletEvent(address user, address walletAddress);

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function makeWallet() public {
		require(_wallets[msg.sender] == address(0));

		address walletAddress = address(new Wallet(msg.sender, msg.sender));
		if (walletAddress != address(0)) {
			_wallets[msg.sender] = walletAddress;
			_users[walletAddress] = msg.sender;

			emit MakeWalletEvent(msg.sender, walletAddress);
		}
	}

	function getWallet(address owner) public view returns (address) {
		return _wallets[owner];
	}

	function getOwner(address walletAddress) public view returns (address) {
		return _users[walletAddress];
	}
}
