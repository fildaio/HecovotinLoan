// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./HTTokenInterface.sol";
import "./Wallet.sol";

interface WalletFactoryInterface {
    function getWallet(address msgSender) external view returns (Wallet);
}

contract HTToken is ERC20, HTTokenInterface {
    address private _factoryAddress;
    WalletFactoryInterface private _factory;

    constructor(uint256 initialSupply) ERC20("HT Token", "HTT") {
        _mint(msg.sender, initialSupply);
    }

    function setFactory(address factory) public {
        _factoryAddress = factory;
        _factory = WalletFactoryInterface(_factoryAddress);
    }

    function mint(uint256 amount, address caller) external override {
        require(msg.sender == address(_factory.getWallet(caller)));
        _mint(msg.sender, amount);
    }

    function burn(uint256 amount, address caller) external override {
        require(msg.sender == address(_factory.getWallet(caller)));
        _burn(msg.sender, amount);
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
