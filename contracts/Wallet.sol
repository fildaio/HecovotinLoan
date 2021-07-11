// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./VotingStrategy.sol";
import "./LoanStrategy.sol";
import "./HTTokenInterface.sol";

contract Wallet is AccessControl {
    using SafeMath for uint256;

    struct RedeemingState {
        uint256 blockNumber;
        uint256 amount;
    }

    struct ClearObject {
        address voter;
        uint256 voteTo;
        uint256 voted;
        uint256 debt;
        address firstClearer;
        address secondClearer;
        uint256 revokeVoteBlock;
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG_ROLE");

    VotingStrategy public votingContract;
    LoanStrategy public loanContract;

    uint256 private _minVoteAmount = 1e18;
    uint256 private _borrowRate = 80;
    uint256 private _emergencyBorrowRate = 98;
    uint256 private _clearRate = 90;
    uint256 private _bonusRateForClearer = 3;
    ClearObject[] private _clearObjects;
    mapping(address => uint256) private _loan;
    mapping(address => uint256) _totalVoted;
    mapping(address => mapping(uint256 => uint256)) private _voted;
    mapping(address => mapping(uint256 => RedeemingState)) private _redeeming;
    mapping(address => mapping(uint256 => RedeemingState))
        private _redeemingWithLoan;
    address payable private _deployedVoteContract = payable(address(0x123));
    address payable private _deployedLoanContract = payable(address(0x123));
    HTTokenInterface private _HTT = HTTokenInterface(address(0x123));

    // Events
    event voteEvent(address voter, uint256 pid, uint256 amount);

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(CONFIG_ROLE, msg.sender);

        votingContract = VotingStrategy(_deployedVoteContract);
        loanContract = LoanStrategy(_deployedLoanContract);
    }

    function setConfigRole(address configRoleAddress) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not admin.");
        _setupRole(CONFIG_ROLE, configRoleAddress);
    }

    function vote(uint256 pid) public payable {
        uint256 amount = msg.value;

        require(amount > _minVoteAmount);

        bool done = votingContract.vote{value: amount}(pid);
        if (done == true) {
            _voted[msg.sender][pid] += amount;
            _totalVoted[msg.sender] += amount;

            _HTT.mint(amount);
            loanContract.mint(amount);

            emit voteEvent(msg.sender, pid, amount);
        }
    }

    function claim() public {
        votingContract.claim(payable(msg.sender));
    }

    function redeem(uint256 pid, uint256 amount) public {
        if (_redeeming[msg.sender][pid].blockNumber == 0) {
            require(_voted[msg.sender][pid] >= amount);
            votingContract.revokeVote(pid, amount);
            _redeeming[msg.sender][pid] = RedeemingState(block.number, amount);
        }

        if (block.number.sub(_redeeming[msg.sender][pid].blockNumber) > 86400) {
            uint256 tempAmount = _redeeming[msg.sender][pid].amount;
            votingContract.redeem(pid, tempAmount);

            _redeeming[msg.sender][pid] = RedeemingState(0, 0);
            _voted[msg.sender][pid] -= tempAmount;
            _totalVoted[msg.sender] -= tempAmount;

            payable(msg.sender).transfer(tempAmount);
        }
    }

    function rePay(uint256 repayAmount) public {
        address payable caller = payable(msg.sender);
        require(caller.balance >= repayAmount);
        loanContract.repayBorrow(caller, repayAmount);
    }

    function redeemAndRePay(uint256 pid, uint256 repayAmount) public {
        require(
            _loan[msg.sender] <=
                _voted[msg.sender][pid].mul(_borrowRate).div(100)
        );

        if (_redeemingWithLoan[msg.sender][pid].blockNumber == 0) {
            votingContract.revokeVote(pid, repayAmount);
            _redeemingWithLoan[msg.sender][pid] = RedeemingState(
                block.number,
                repayAmount
            );
        }

        if (
            block.number.sub(_redeemingWithLoan[msg.sender][pid].blockNumber) >
            86400
        ) {
            uint256 amount = _redeemingWithLoan[msg.sender][pid].amount;
            _redeemingWithLoan[msg.sender][pid] = RedeemingState(0, 0);
            _voted[msg.sender][pid] -= amount;
            _totalVoted[msg.sender] -= amount;

            votingContract.redeem(pid, amount);
            loanContract.repayBorrow(payable(msg.sender), amount);
        }
    }

    function clear(uint256 index) public {
        ClearObject storage tempClearObject = _clearObjects[index];

        if (tempClearObject.revokeVoteBlock == 0) {
            votingContract.revokeVote(
                tempClearObject.voteTo,
                tempClearObject.voted
            );
            tempClearObject.firstClearer = msg.sender;
        }

        if (block.number.sub(tempClearObject.revokeVoteBlock) > 86400) {
            votingContract.redeem(
                tempClearObject.voteTo,
                tempClearObject.voted
            );
            tempClearObject.secondClearer = msg.sender;

            loanContract.repayBorrow(
                payable(tempClearObject.voter),
                tempClearObject.debt
            );

            _HTT.burn(tempClearObject.voted);

            _voted[tempClearObject.voter][tempClearObject.voteTo] -= tempClearObject.voted;
            _totalVoted[tempClearObject.voter] -= tempClearObject.voted;
            _loan[tempClearObject.voter] -= tempClearObject.voted;

            uint256 bonus = tempClearObject
            .voted
            .mul(_bonusRateForClearer)
            .div(100)
            .div(2);
            payable(tempClearObject.firstClearer).transfer(bonus);
            payable(tempClearObject.secondClearer).transfer(bonus);

            delete _clearObjects[index];
        }
    }

    function borrow(uint256 pid, uint256 borrowAmount) public {
        require(borrowAmount > 0);
        require(
            borrowAmount <= _voted[msg.sender][pid].mul(_borrowRate).div(100)
        );

        loanContract.borrow(borrowAmount);
        payable(msg.sender).transfer(borrowAmount);
        _loan[msg.sender] += borrowAmount;

        _setAsClearable(pid);
    }

    function emergencyWithdraw(uint256 pid, uint256 borrowAmount) public {
        require(borrowAmount > 0);
        require(
            borrowAmount <=
                _totalVoted[msg.sender].mul(_emergencyBorrowRate).div(100)
        );
        loanContract.borrow(borrowAmount);
        payable(msg.sender).transfer(borrowAmount);

        _setAsClearable(pid);
    }

    function _setAsClearable(uint256 pid) private {
        if (
            _loan[msg.sender] >=
            _totalVoted[msg.sender].mul(_clearRate).div(100)
        ) {
            _clearObjects.push(
                ClearObject(
                    msg.sender,
                    pid,
                    _voted[msg.sender][pid],
                    _loan[msg.sender],
                    address(0),
                    address(0),
                    0
                )
            );
        }
    }
}
