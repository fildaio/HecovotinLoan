// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HTTokenInterface.sol";

interface WalletFactoryInterface {
    function getOwner(address walletAddress) external view returns (address);
}

contract HTToken is ERC20, HTTokenInterface {
    WalletFactoryInterface private _factory;

    constructor(uint256 initialSupply) ERC20("HT Token", "HTT") {
        _mint(msg.sender, initialSupply);
    }

    function setFactory(address factory) public {
        _factory = WalletFactoryInterface(factory);
    }

    function mint(uint256 amount) external override {
        require(_factory.getOwner(msg.sender) != address(0));
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount) external override {
        require(_factory.getOwner(msg.sender) != address(0));
        _burn(msg.sender, amount);
    }

    function transferTo(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        require(_factory.getOwner(msg.sender) != address(0));
        return transfer(recipient, amount);
    }

    function balance(address userAddress)
        external
        view
        override
        returns (uint256)
    {
        return balanceOf(userAddress);
    }
}
