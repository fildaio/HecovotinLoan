// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./LoanStrategy.sol";
import "./HTToken.sol";

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
	// function exchangeRateCurrent() public returns (uint);
	// function exchangeRateStored() public view returns (uint);
	// function getCash() external view returns (uint);
	// function accrueInterest() public returns (uint);
	// function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
	function borrowBalanceCurrent(address account) external returns (uint256);

	function balanceOfUnderlying(address owner) external returns (uint256);
}

interface MaximillionInterface {
	function repayBehalf(address borrower) external payable;
}

contract LoanViaFilda is LoanStrategy {
	HTToken public HTT = HTToken(address(0x123));
	FildaInterface public filda = FildaInterface(0x824151251B38056d54A15E56B73c54ba44811aF8);
	CTokenInterface public qToken = CTokenInterface(0x824151251B38056d54A15E56B73c54ba44811aF8);
	MaximillionInterface public maximillion = MaximillionInterface(0x32fbB9c822ABd1fD9e4655bfA55A45285Fb8992d);

	function borrow(uint256 borrowAmount) external payable override {
		filda.borrow(borrowAmount);
	}

	function mint(uint256 mintAmount) external override {
		filda.mint(mintAmount);
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
		return qToken.borrowBalanceCurrent(user);
	}

	function getSavingBalance(address owner) external override returns (uint256) {
		return qToken.balanceOfUnderlying(owner);
	}
}
