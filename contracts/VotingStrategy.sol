// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface VotingStrategy {
    function vote(uint256 pid) external payable returns (bool);

    function revokeVote(uint256 pid, uint256 amount) external;

    function withdraw() external;

    function redeem(uint256 pid, uint256 amount) external;

    function claim(address payable sender) external;

    function reinvest() external payable;

    function userInfo(address userAddress)
        external
        returns (uint256 votedHT, uint256 ownedHTT);
}
