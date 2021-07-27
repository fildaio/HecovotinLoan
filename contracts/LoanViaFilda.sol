// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LoanStrategy.sol";
import "./HTToken.sol";
import "./Global.sol";

interface flashLoanInterface {
	function mint(uint256 mintAmount) external returns (uint256);

	function borrow(uint256 borrowAmount) external returns (uint256);

	function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

	function repayBorrow(uint256 repayAmount) external returns (uint256);
}

interface CTokenInterface {
	function borrowIndex() external view returns (uint256);

	function borrowBalanceStored(address account) external view returns (uint256);

	function borrowBalanceCurrent(address account) external returns (uint256);

	function balanceOfUnderlying(address owner) external returns (uint256);

	function exchangeRateCurrent() external returns (uint256);

	function balanceOf(address owner) external view returns (uint256);
}

interface MaximillionInterface {
	function repayBehalf(address borrower) external payable;
}

interface CompInterface {
	function balanceOf(address account) external view returns (uint256);
}

interface ComptrollerInterface {
	// function markets(address) external view returns (bool, uint256);
	// function oracle() external view returns (PriceOracle);
	// function getAccountLiquidity(address)
	// 	external
	// 	view
	// 	returns (
	// 		uint256,
	// 		uint256,
	// 		uint256
	// 	);
	// function getAssetsIn(address) external view returns (CToken[] memory);
	function claimComp(address) external;

	function claimComp(address user, CTokenInterface[] memory tokens) external;

	function compAccrued(address) external view returns (uint256);
}

interface CompoundLensInterface {
	function getCompBalanceWithAccrued(
		CompInterface comp,
		ComptrollerInterface comptroller,
		address account
	) external returns (uint256 balance, uint256 allocated);
}

contract LoanViaFilda is LoanStrategy, AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	address public compContractAddress;
	address public comptrollerAddress;
	address public cTokenAddress;
	CompoundLensInterface public compoundLens;
	flashLoanInterface public flashLoan;
	CTokenInterface public cToken;
	MaximillionInterface public maximillion;
	ComptrollerInterface public comptroller;

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function setCTokenAddress(address contractAddress) public {
		_byAdmin();
		cTokenAddress = contractAddress;
		cToken = CTokenInterface(contractAddress);
	}

	function setCompoundLens(address contractAddress) public {
		_byAdmin();
		compoundLens = CompoundLensInterface(contractAddress);
	}

	function setFlashLoan(address contractAddress) public {
		_byAdmin();
		flashLoan = flashLoanInterface(contractAddress);
	}

	function setQToken(address contractAddress) public {
		_byAdmin();
		cToken = CTokenInterface(contractAddress);
	}

	function setMaximillion(address contractAddress) public {
		_byAdmin();
		maximillion = MaximillionInterface(contractAddress);
	}

	function setCompContractAddress(address contractAddress) public {
		_byAdmin();
		compContractAddress = contractAddress;
	}

	function setComptrollerAddress(address contractAddress) public {
		_byAdmin();
		comptrollerAddress = contractAddress;
		comptroller = ComptrollerInterface(contractAddress);
	}

	function borrow(uint256 borrowAmount) external payable override returns (uint256) {
		return flashLoan.borrow(borrowAmount);
	}

	function mint(uint256 mintAmount) external override returns (uint256) {
		return flashLoan.mint(mintAmount);
	}

	function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
		return flashLoan.redeemUnderlying(redeemAmount);
	}

	function repayBehalf(address who) external payable override returns (bool) {
		try maximillion.repayBehalf{ value: msg.value }(who) {
			return true;
		} catch {
			return false;
		}
	}

	function borrowBalanceCurrent(address user) external override returns (uint256) {
		// return cToken.borrowBalanceStored(user);
		return cToken.borrowBalanceCurrent(user);
	}

	function getSavingBalance(address owner) external view override returns (uint256) {
		// return cToken.balanceOfUnderlying(owner);
		return cToken.balanceOf(owner);
	}

	function getCompBalanceWithAccrued(address owner) external override returns (uint256 balance, uint256 allocated) {
		return compoundLens.getCompBalanceWithAccrued(CompInterface(compContractAddress), ComptrollerInterface(comptrollerAddress), owner);
	}

	function claimComp(address owner) external override returns (bool) {
		CTokenInterface[] memory args = new CTokenInterface[](1);
		args[0] = cToken;
		try comptroller.claimComp(owner, args) {
			return true;
		} catch {
			return false;
		}
	}

	function exchangeRateCurrent() external override returns (uint256) {
		return cToken.exchangeRateCurrent();
	}

	function _byAdmin() private view {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
	}
}
