// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Wallet.sol";
import "./WalletFactoryInterface.sol";

contract WalletFactory is WalletFactoryInterface {
	mapping(address => address) private _wallets;
	mapping(address => address) private _users;

	event MakeWalletEvent(address user, address walletAddress);

	function makeWallet(address configAddress) public {
		require(_wallets[msg.sender] == address(0), "Wallet exists");

		address walletAddress = address(new Wallet(msg.sender, msg.sender, configAddress));
		_wallets[msg.sender] = walletAddress;
		_users[walletAddress] = msg.sender;

		emit MakeWalletEvent(msg.sender, walletAddress);
	}

	function getWallet(address owner) public view returns (address) {
		return _wallets[owner];
	}

	function getOwner(address walletAddress) public view override returns (address) {
		return _users[walletAddress];
	}
}
