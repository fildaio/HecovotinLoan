// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface LoanStrategy {
    function borrow(uint256 borrowAmount) external payable;

    function mint(uint256 mintAmount) external;

    function redeemUnderlying(uint256 redeemAmount) external;

    function repayBorrow(address payable who, uint256 repayAmount) external;
}
