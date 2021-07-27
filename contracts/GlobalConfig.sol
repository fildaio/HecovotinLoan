// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./VotingStrategy.sol";
import "./LoanStrategy.sol";
import "./HTTokenInterface.sol";

contract GlobalConfig is AccessControl {
	bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
	bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

	bool public voteOn = true;
	bool public withdrawalOn = true;
	uint256 public decimals = 1e18;
	uint256 public denominator = 10000;
	uint256 public borrowRate = 8000;
	uint256 public borrowQuicklyRate = 9700;
	uint256 public liquidateRate = 9000;
	uint256 public bonusRateForLiquidater = 300;
	IERC20 public filda;
	HTTokenInterface public HTT;
	VotingStrategy public votingContract;
	LoanStrategy public loanContract;

	constructor() {
		_setupRole(ADMIN_ROLE, msg.sender);
		_setupRole(CONFIG_ROLE, msg.sender);
	}

	function setConfigRole(address configRoleAddress) public {
		_byAdmin();
		_setupRole(CONFIG_ROLE, configRoleAddress);
	}

	function setVoteOn(bool value) public {
		_byAdmin();
		voteOn = value;
	}

	function setWithdrawalOn(bool value) public {
		_byAdmin();
		withdrawalOn = value;
	}

	function setHTToken(address contractAddress) public {
		_byConfigRole();
		HTT = HTTokenInterface(contractAddress);
	}

	function setFilda(address contractAddress) public {
		_byConfigRole();
		filda = IERC20(contractAddress);
	}

	function setVotingContract(address contractAddress) public {
		_byConfigRole();
		votingContract = VotingStrategy(contractAddress);
	}

	function setLoanContract(address contractAddress) public {
		_byConfigRole();
		loanContract = LoanStrategy(contractAddress);
	}

	function setHTTokenDecimals(uint256 value) public {
		_byConfigRole();
		decimals = value;
	}

	function setDenominator(uint256 value) public {
		_byConfigRole();
		denominator = value;
	}

	function setBorrowRate(uint256 value) public {
		_byConfigRole();
		borrowRate = value;
	}

	function setBorrowQuicklyRate(uint256 value) public {
		_byConfigRole();
		borrowQuicklyRate = value;
	}

	function setLiquidateRate(uint256 value) public {
		_byConfigRole();
		liquidateRate = value;
	}

	function setBonusRateForLiquidater(uint256 value) public {
		_byConfigRole();
		bonusRateForLiquidater = value;
	}

	function _byAdmin() private view {
		require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
	}

	function _byConfigRole() private view {
		require(hasRole(CONFIG_ROLE, msg.sender) || hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin or the configuration roles..");
	}
}
