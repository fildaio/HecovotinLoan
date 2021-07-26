// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HTTokenInterface.sol";
import "./WalletFactoryInterface.sol";

contract HTToken is ERC20, HTTokenInterface {
	using SafeMath for uint256;

	WalletFactoryInterface private _factory;

	constructor(uint256 initialSupply) ERC20("HT Token", "HTT") {
		_mint(msg.sender, initialSupply);
	}

	function setFactory(address factory) public {
		_factory = WalletFactoryInterface(factory);
	}

	function mint(uint256 amount) external override returns (bool) {
		_isWalletContract();
		uint256 oldBalance = balanceOf(msg.sender);
		_mint(msg.sender, amount);
		uint256 newBalance = balanceOf(msg.sender);
		if (newBalance.sub(oldBalance) >= amount) {
			return true;
		} else {
			return false;
		}
	}

	function burn(uint256 amount) external override returns (bool) {
		_isWalletContract();
		uint256 oldBalance = balanceOf(msg.sender);
		_burn(msg.sender, amount);
		uint256 newBalance = balanceOf(msg.sender);
		if (oldBalance.sub(newBalance) >= amount) {
			return true;
		} else {
			return false;
		}
	}

	function transferTo(address recipient, uint256 amount) external override returns (bool) {
		_isWalletContract();
		return transfer(recipient, amount);
	}

	function _isWalletContract() private view {
		require(_factory.getOwner(msg.sender) != address(0));
	}
}
