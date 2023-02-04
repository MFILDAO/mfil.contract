// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./MIntf.sol";
import "./MOwner.sol";

contract MConfig is MOwnable, IConfig {

    address private _encodeAddress;

    address private _mdaoAddress;

    address private _mnftAddress;

    address private _mfilAddress;

    address private _mstakerAddress;

    address private _logicAddress;

    address private _fil2MfilAccount;
    address private _mfil2FilAccount;
    address private _profitAccount;

    function fil2MfilAccount() public view returns(address) {
        return _fil2MfilAccount;
    }

    function setFil2MfilAccount(address addr) public onlyAddrOrOwner(_mdaoAddress) {
        _fil2MfilAccount = addr;
    }

    function mfil2FilAccount() public view returns(address) {
        return _mfil2FilAccount;
    }

    function setMfil2FilAccount(address addr) public onlyAddrOrOwner(_mdaoAddress) {
        _mfil2FilAccount = addr;
    }

    function profitAccount() public view returns(address) {
        return _profitAccount;
    }

    function setProfitAccount(address addr) public onlyAddrOrOwner(_mdaoAddress) {
        _profitAccount = addr;
    }

    function encodeAddress() public view returns(address) {
        return _encodeAddress;
    }

    function setEncodeAddress(address addr) public onlyAddrOrOwner(_mdaoAddress) {
        _encodeAddress = addr;
    }

    function mstakerAddress() public view returns(address) {
        return _mstakerAddress;
    }

    function setMStakerAddress(address addr) public onlyAddrOrOwner(_mdaoAddress) { 
        _mstakerAddress = addr;
    }

    function mnftAddress() public view returns(address) {
        return _mnftAddress;
    }

    function setMNftAddress(address addr) public onlyAddrOrOwner(_mdaoAddress) { 
        _mnftAddress = addr;
    }

    function mfilAddress() public view returns(address) {
        return _mfilAddress;
    }

    function setMfilAddress(address addr) public onlyAddrOrOwner(_mdaoAddress) { 
        _mfilAddress = addr;
    }
    
    function mdaoAddress() public view returns(address) {
        return _mdaoAddress;
    }

    function setMDaoAddress(address addr) public onlyAddrOrOwner(_mdaoAddress) { 
        _mdaoAddress = addr;
    }

    function logicAddress() public view returns(address) {
        return _logicAddress;
    }

    function setLogicAddress(address addr) public onlyAddrOrOwner(_mdaoAddress) { 
        _logicAddress = addr;
    }
}