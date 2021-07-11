// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./VotingStrategy.sol";
import "./HTTokenInterface.sol";

interface HecoNodeVoteInterface {
    function vote(uint256 pid) external payable;

    function revokeVote(uint256 pid, uint256 amount) external;

    function redeem(uint256 pid, uint256 amount) external;

    function claim() external returns (uint256);
}

contract HecoNodeVote is VotingStrategy {
    HTTokenInterface public HTT = HTTokenInterface(address(0x123));
    HecoNodeVoteInterface public voting =
        HecoNodeVoteInterface(0x80d1769ac6fee59BE5AAC1952a90270bbd2Ceb2F);

    mapping(address => uint256) voted;

    function vote(uint256 pid) external payable override returns (bool) {
        voting.vote{value: msg.value}(pid);
        return true;
    }

    function revokeVote(uint256 pid, uint256 amount) external override {
        voting.revokeVote(pid, amount);
    }

    function withdraw() external override {}

    function redeem(uint256 pid, uint256 amount) external override {
        voting.redeem(pid, amount);
    }

    function claim(address payable sender) external override {
        uint256 result = voting.claim();
        require(result > 0);
        sender.transfer(result);
    }

    function reinvest() external payable override {}

    function userInfo(address userAddress)
        external
        view
        override
        returns (uint256 votedHT, uint256 ownedHTT)
    {
        votedHT = voted[userAddress];
        ownedHTT = HTT.balance(userAddress);
    }
}
