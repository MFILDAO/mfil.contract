// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract MAccount{
    address private _owner;
    address private _manager;

    event Deposit(address, uint256);
    event Withdraw(address, address, uint256);

    modifier onlyOwner() {
        require(msg.sender == _owner, "not owner");
        _;
    }

    modifier onlyManager() {
        require(msg.sender == _manager, "not manager");
        _;
    }

    constructor() {
        _owner = msg.sender;
    }

    function chown(address owner) onlyOwner public {
        _owner = owner;
    }

    function owner() public view returns(address) {
        return _owner;
    }

    function chmgr(address manager) onlyOwner public {
        _manager = manager;
    }

    function manager() public view returns(address) {
        return _manager;
    }

    receive() external payable {
        if (msg.value > 0) {
            emit Deposit(msg.sender, msg.value);
        }
    }

    function withdraw(address account, uint256 amount) onlyManager public {
        require(amount <= address(this).balance, "not enough amount");
        (bool success,) = account.call{value: amount}("");
        require(success, "withdraw failed");
        emit Withdraw(msg.sender, account, amount);
    }
}
  

