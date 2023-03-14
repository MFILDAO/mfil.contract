// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/proxy/beacon/BeaconProxy.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/proxy/beacon/UpgradeableBeacon.sol";

contract StakerProxy is BeaconProxy, Ownable {
    constructor(address beacon, bytes memory data) BeaconProxy(beacon, data) {}

    function upgradeProxy(address newBeacon, bytes memory data)
        public
        onlyOwner
    {
        _upgradeBeaconToAndCall(newBeacon, data, false);
    }
}