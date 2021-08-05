// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HTTokenInterface.sol";
import "./WalletFactoryInterface.sol";

contract HTToken is ERC20, HTTokenInterface, AccessControl {
	using SafeMath for uint256;

	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	WalletFactoryInterface private _factory;

	constructor() ERC20("HT Token", "HTT") {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function setFactory(address factory) public {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
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

	function _isWalletContract() private view {
		require(_factory.getOwner(msg.sender) != address(0), "no wallet");
	}
}
