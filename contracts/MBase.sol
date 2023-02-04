// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MIntf.sol";
import "./MOwner.sol";

contract MBase is MOwnable {
    address private CONFIG_CONTRACT = address(0);

    constructor(address configContract_) {
        CONFIG_CONTRACT = configContract_;
    }

    modifier onlyLogicOrOwner() {
        require(
            _msgSender() == configContract().logicAddress() ||
                owner() == _msgSender(),
            "only call by logic contract or owner"
        );
        _;
    }

    modifier onlyLogic() {
        require(
            _msgSender() == configContract().logicAddress(),
            "only call by logic contract"
        );
        _;
    }

    function setConfigContract(address configContract_) public onlyOwner() {
        CONFIG_CONTRACT = configContract_;
    }

    function configContract() public view returns (IConfig) {
        return IConfig(CONFIG_CONTRACT);
    }

    function getMNftContract() internal view returns (IMNft) {
        return IMNft(configContract().mnftAddress());
    }

    function getMFilContract() internal view returns (IMfil) {
        return IMfil(configContract().mfilAddress());
    }
}
