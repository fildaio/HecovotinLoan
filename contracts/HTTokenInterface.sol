// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface HTTokenInterface is IERC20 {
    function mint(uint256 amount, address caller) external;

    function burn(uint256 amount, address caller) external;

    function balance(address userAddress) external view returns (uint256);
}
