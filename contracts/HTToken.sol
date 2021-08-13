// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HTTokenInterface.sol";
import "./WalletFactoryInterface.sol";

contract HTToken is ERC20, HTTokenInterface, AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	WalletFactoryInterface private _factory;

	constructor(string memory name, string memory symbol) ERC20(name, symbol) {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function setFactory(address factory) public {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
		_factory = WalletFactoryInterface(factory);
	}

	function mint(uint256 amount) external override returns (bool) {
		_isWalletContract();
		_mint(msg.sender, amount);
		return true;
	}

	function burn(uint256 amount) external override returns (bool) {
		_isWalletContract();
		_burn(msg.sender, amount);
		return true;
	}

	function _isWalletContract() private view {
		require(_factory.getOwner(msg.sender) != address(0), "no wallet");
	}
}
