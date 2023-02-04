// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "./MIntf.sol";

import "./MBase.sol";

contract MFil is 
    MBase,
    IMfil,
    ERC20 {

    constructor(
        address configContract_,
        string memory name_,
        string memory symbol_
        
    ) ERC20(name_, symbol_) MBase(configContract_) {
         
    }

    function logicMint(address account, uint256 amount) external 
        onlyLogic() 
        returns (uint256) {

        _mint(account, amount);

        return totalSupply();
    }

    function logicBurn(address account, uint256 amount) external
        onlyLogic() {
        address spender = _msgSender();
        _spendAllowance(account, spender, amount);
        _burn(account, amount);
    }
    
}
  

