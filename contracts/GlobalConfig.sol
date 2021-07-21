// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./VotingStrategy.sol";
import "./LoanStrategy.sol";
import "./HTTokenInterface.sol";

contract GlobalConfig is AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
	bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

	uint256 public decimals = 1e18;
	uint256 public denominator = 10000;
	uint256 public borrowRate = 8000;
	uint256 public borrowQuicklyRate = 9700;
	uint256 public liquidateRate = 9000;
	uint256 public bonusRateForLiquidater = 300;
	HTTokenInterface public HTT = HTTokenInterface(address(0x123));
	VotingStrategy public votingContract = VotingStrategy(address(0x123));
	LoanStrategy public loanContract = LoanStrategy(address(0x123));

	modifier byAdmin() {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
		_;
	}

	modifier byConfigRole() {
		require(hasRole(CONFIG_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin or the configuration roles..");
		_;
	}

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
		_setupRole(CONFIG_ROLE, msg.sender);
	}

	function setConfigRole(address configRoleAddress) public byAdmin() {
		_setupRole(CONFIG_ROLE, configRoleAddress);
	}

	function setHTToken(address contractAddress) public byConfigRole() {
		HTT = HTTokenInterface(contractAddress);
	}

	function setVotingContract(address contractAddress) public byConfigRole() {
		votingContract = VotingStrategy(contractAddress);
	}

	function setLoanContract(address contractAddress) public byConfigRole() {
		loanContract = LoanStrategy(contractAddress);
	}

	function setHTTokenDecimals(uint256 value) public byConfigRole() {
		decimals = value;
	}

	function setDenominator(uint256 value) public byConfigRole() {
		denominator = value;
	}

	function setBorrowRate(uint256 value) public byConfigRole() {
		borrowRate = value;
	}

	function setBorrowQuicklyRate(uint256 value) public byConfigRole() {
		borrowQuicklyRate = value;
	}

	function setLiquidateRate(uint256 value) public byConfigRole() {
		liquidateRate = value;
	}

	function setBonusRateForLiquidater(uint256 value) public byConfigRole() {
		bonusRateForLiquidater = value;
	}
}
