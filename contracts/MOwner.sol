// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MOwnable is Ownable {
    modifier onlyAddrOrOwner(address addr) {
        require(
            owner() == _msgSender() ||
                (addr != address(0) && _msgSender() == addr),
            "Ownable: caller is not the owner or defined address"
        );
        _;
    }
}