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
	function borrowBalanceCurrent(address account) external returns (uint256);

	function balanceOfUnderlying(address owner) external returns (uint256);

	function exchangeRateCurrent() external returns (uint256);
}

interface MaximillionInterface {
	function repayBehalf(address borrower) external payable;
}

interface CompoundLensInterface is Global {
	function getCompBalanceWithAccrued(
		address compContractAddress,
		address comptrollerAddress,
		address user
	) external returns (CompBalance memory);
}

interface ComptrollerInterface {
	function claimComp(address user, address[1] memory tokens) external;
}

contract LoanViaFilda is LoanStrategy, AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	address public compContractAddress = 0xE36FFD17B2661EB57144cEaEf942D95295E637F0;
	address public comptrollerAddress = 0xb74633f2022452f377403B638167b0A135DB096d;
	address public cTokenAddress = 0x824151251B38056d54A15E56B73c54ba44811aF8;
	CompoundLensInterface public compoundLens = CompoundLensInterface(0x824522f5a2584dCa56b1f05e6b41C584b3FDA4a3);
	flashLoanInterface public flashLoan = flashLoanInterface(0x824151251B38056d54A15E56B73c54ba44811aF8);
	CTokenInterface public cToken = CTokenInterface(cTokenAddress);
	MaximillionInterface public maximillion = MaximillionInterface(0x32fbB9c822ABd1fD9e4655bfA55A45285Fb8992d);
	ComptrollerInterface public comptroller = ComptrollerInterface(comptrollerAddress);

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function setCTokenAddress(address contractAddress) public {
		_byAdmin();
		cTokenAddress = contractAddress;
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
		return cToken.borrowBalanceCurrent(user);
	}

	function getSavingBalance(address owner) external override returns (uint256) {
		return cToken.balanceOfUnderlying(owner);
	}

	function getCompBalanceWithAccrued(address owner) external override returns (uint256) {
		CompBalance memory compBalance = compoundLens.getCompBalanceWithAccrued(compContractAddress, comptrollerAddress, owner);
		return compBalance.balance;
	}

	function claimComp(address owner) external override returns (bool) {
		address[1] memory args = [cTokenAddress];
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
