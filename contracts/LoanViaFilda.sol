// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LoanStrategy.sol";
import "./HTToken.sol";
import "./Global.sol";

interface FildaInterface {
	// function liquidateBorrow(address borrower, address cTokenCollateral) external payable;
	// function repayBorrowBehalf(address borrower) external payable;
	// function repayBorrow() external payable;
	// ============================
	// function borrow(uint borrowAmount) external returns (uint);
	// function redeem(uint redeemTokens) external returns (uint);
	// function liquidateBorrow(address borrower, uint repayAmount, CTokenInterface cTokenCollateral) external returns (uint);
	function mint(uint256 mintAmount) external returns (uint256);

	function borrow(uint256 borrowAmount) external returns (uint256);

	function redeemUnderlying(uint256 redeemAmount) external returns (uint256);

	function repayBorrow(uint256 repayAmount) external returns (uint256);

	// function repayBorrowBehalf(address borrower, uint256 repayAmount) external returns (uint256);
}

interface CTokenInterface {
	// function transfer(address dst, uint amount) external returns (bool);
	// function transferFrom(address src, address dst, uint amount) external returns (bool);
	// function approve(address spender, uint amount) external returns (bool);
	// function allowance(address owner, address spender) external view returns (uint);
	// function balanceOf(address owner) external view returns (uint);
	// function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
	// function borrowRatePerBlock() external view returns (uint);
	// function supplyRatePerBlock() external view returns (uint);
	// function totalBorrowsCurrent() external returns (uint);
	// function borrowBalanceStored(address account) public view returns (uint);
	// function exchangeRateStored() public view returns (uint);
	// function getCash() external view returns (uint);
	// function accrueInterest() public returns (uint);
	// function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
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
	function claimComp(address user, address[] memory tokens) external;
}

contract LoanViaFilda is LoanStrategy, AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	address public compContractAddress = 0xE36FFD17B2661EB57144cEaEf942D95295E637F0;
	address public comptrollerAddress = 0xb74633f2022452f377403B638167b0A135DB096d;
	address public cTokenAddress = 0x824151251B38056d54A15E56B73c54ba44811aF8;
	CompoundLensInterface public compoundLens = CompoundLensInterface(0x824522f5a2584dCa56b1f05e6b41C584b3FDA4a3);
	FildaInterface public filda = FildaInterface(0x824151251B38056d54A15E56B73c54ba44811aF8);
	CTokenInterface public cToken = CTokenInterface(cTokenAddress);
	MaximillionInterface public maximillion = MaximillionInterface(0x32fbB9c822ABd1fD9e4655bfA55A45285Fb8992d);
	ComptrollerInterface public comptroller = ComptrollerInterface(comptrollerAddress);

	modifier byAdmin() {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
		_;
	}

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
	}

	function setCTokenAddress(address contractAddress) public byAdmin() {
		cTokenAddress = contractAddress;
	}

	function setCompoundLens(address contractAddress) public byAdmin() {
		compoundLens = CompoundLensInterface(contractAddress);
	}

	function setFilda(address contractAddress) public byAdmin() {
		filda = FildaInterface(contractAddress);
	}

	function setQToken(address contractAddress) public byAdmin() {
		cToken = CTokenInterface(contractAddress);
	}

	function setMaximillion(address contractAddress) public byAdmin() {
		maximillion = MaximillionInterface(contractAddress);
	}

	function setCompContractAddress(address contractAddress) public byAdmin() {
		compContractAddress = contractAddress;
	}

	function setComptrollerAddress(address contractAddress) public byAdmin() {
		comptrollerAddress = contractAddress;
	}

	function borrow(uint256 borrowAmount) external payable override returns (uint256) {
		return filda.borrow(borrowAmount);
	}

	function mint(uint256 mintAmount) external override returns (uint256) {
		return filda.mint(mintAmount);
	}

	function redeemUnderlying(uint256 redeemAmount) external override returns (uint256) {
		return filda.redeemUnderlying(redeemAmount);
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
		address[] memory args = new address[](1);
		args[0] = cTokenAddress;
		try comptroller.claimComp(owner, args) {
			return true;
		} catch {
			return false;
		}
	}

	function exchangeRateCurrent() external override returns (uint256) {
		return cToken.exchangeRateCurrent();
	}
}
