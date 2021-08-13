// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LoanInterface.sol";
import "./HTToken.sol";
import "./ComptrollerInterface.sol";

interface CompInterface {
	function balanceOf(address account) external view returns (uint256);
}

interface CompoundLensInterface {
	function getCompBalanceWithAccrued(
		CompInterface comp,
		ComptrollerInterface comptroller,
		address account
	) external returns (uint256 balance, uint256 allocated);
}

contract LoanViaFilda is LoanInterface, AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

	address public compContractAddress;
	CompoundLensInterface public compoundLens;
	address public comptrollerAddress;
	address public cTokenAddress;
	CTokenInterface public cToken;

	constructor(
		address argCompContract,
		address argCompoundLensContract,
		address argComptrollerContract,
		address argCTokenContract
	) {
		_setupRole(ADMIN_ROLE, msg.sender);

		compContractAddress = argCompContract;
		compoundLens = CompoundLensInterface(argCompoundLensContract);
		comptrollerAddress = argComptrollerContract;
		cTokenAddress = argCTokenContract;
	}

	function setCTokenAddress(address contractAddress) public {
		_byAdmin();
		cTokenAddress = contractAddress;
	}

	function setCompoundLens(address contractAddress) public {
		_byAdmin();
		compoundLens = CompoundLensInterface(contractAddress);
	}

	function setCompContractAddress(address contractAddress) public {
		_byAdmin();
		compContractAddress = contractAddress;
	}

	function setComptrollerAddress(address contractAddress) public {
		_byAdmin();
		comptrollerAddress = contractAddress;
	}

	function borrowBalanceCurrent(address user) external override returns (uint256) {
		// return cToken.borrowBalanceStored(user);
		return CTokenInterface(cTokenAddress).borrowBalanceCurrent(user);
	}

	function getCompBalanceWithAccrued(address owner) external override returns (uint256 balance, uint256 allocated) {
		return compoundLens.getCompBalanceWithAccrued(CompInterface(compContractAddress), ComptrollerInterface(comptrollerAddress), owner);
	}

	function claimComp(address owner) external override returns (bool) {
		CTokenInterface[] memory args = new CTokenInterface[](1);
		args[0] = CTokenInterface(cTokenAddress);
		ComptrollerInterface(comptrollerAddress).claimComp(owner, args);
		return true;
	}

	function exchangeRateCurrent() external override returns (uint256) {
		return CTokenInterface(cTokenAddress).exchangeRateCurrent();
	}

	function _byAdmin() private view {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
	}
}
