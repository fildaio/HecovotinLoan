// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LoanStrategy.sol";
import "./HTToken.sol";
import "./Global.sol";

interface CTokenInterface {
	function borrowIndex() external view returns (uint256);

	function borrowBalanceStored(address account) external view returns (uint256);

	function borrowBalanceCurrent(address account) external returns (uint256);

	function balanceOfUnderlying(address owner) external returns (uint256);

	function exchangeRateCurrent() external returns (uint256);
}

interface MaximillionInterface {
	function repayBehalf(address borrower) external payable;
}

interface CompInterface {
	function balanceOf(address account) external view returns (uint256);
}

interface ComptrollerInterface {
	function claimComp(address) external;

	function claimComp(address user, CTokenInterface[] memory tokens) external;

	function compAccrued(address) external view returns (uint256);

	function enterMarkets(address[] memory cTokens) external returns (uint256[] memory);
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
	// flashLoanInterface public flashLoan;
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

	function enterMarkets(address depositToken) external override returns (uint256[] memory) {
		address[] memory args = new address[](1);
		args[0] = depositToken;
		return comptroller.enterMarkets(args);
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
