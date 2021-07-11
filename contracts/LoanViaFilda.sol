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

    function repayBorrowBehalf(address borrower, uint256 repayAmount)
        external
        returns (uint256);
}

contract LoanViaFilda is LoanStrategy {
    HTToken public HTT = HTToken(address(0x123));
    FildaInterface public filda = FildaInterface(address(0x123));

    function borrow(uint256 borrowAmount) external payable override {
        filda.borrow(borrowAmount);
    }

    function mint(uint256 mintAmount) external override {
        filda.mint(mintAmount);
    }

    function redeemUnderlying(uint256 redeemAmount) external override {
        filda.redeemUnderlying(redeemAmount);
    }

    function repayBorrow(address payable who, uint256 repayAmount)
        external
        override
    {
        filda.repayBorrowBehalf(who, repayAmount);
    }
}
