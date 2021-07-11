// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HTTokenInterface.sol";

contract HTToken is ERC20, HTTokenInterface {
    constructor(uint256 initialSupply) ERC20("HT Token", "HTT") {
        _mint(msg.sender, initialSupply);
    }

    function mint(uint256 amount) external override {
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
    }

    function balance(address userAddress) external view override returns (uint256) {
        return balanceOf(userAddress);
    }
}
