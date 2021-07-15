// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Wallet.sol";

contract WalletFactory is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(address => Wallet) wallets;

    constructor() {
        _setupRole(ADMIN_ROLE, msg.sender);
    }

    function makeWallet() public {
        require(wallets[msg.sender].isExist() == false);
        wallets[msg.sender] = new Wallet(msg.sender);
    }

    function getWallet(address owner) public view returns (Wallet) {
        return wallets[owner];
    }
}
