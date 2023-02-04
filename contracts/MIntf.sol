// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct MintParams {
    uint256 txID;
    address account;
    uint256 tokenID;
    string uri;
    uint256 minerID;
    uint256 pledgeAmount;
    uint256 expireDate;
}

struct ExchangeParams {
    uint256 txID;
    address account;
    uint256 amount;
    string filAddr;
}

struct BurnParams {
    uint256 txID;
    address account;
    uint256 minerID;
    uint256 tokenID;
}

struct TakeProfitParams {
    uint256 txID;
    address account;
    uint256 profit;
    string filAddr;
}

struct StakeParams {
    uint256 txID;
    address account;
    uint256 amount;
}

struct UnstakeParams {
    uint256 txID;
    address account;
    uint256 amount;
}


struct ProfitRate { 
    // The accuracy of the interest rate is calculated in thousands, and the calculation result needs to be divided by 1000
    uint256 rate;
    uint256 date;
}

struct Stake {
    uint256 date;
    uint256 profit;
    uint256 amount;
    uint256 profitStartFactor;
}

struct MinerToken {
    uint256 minerID;
    uint256 expireDate;
    uint256 pledgeAmount;
    string tokenUri;
}

interface IMfil {
    function logicMint(address account, uint256 amount) external returns (uint256);

    function logicBurn(address account, uint256 amount) external;
}

interface IMNft {
    function logicMint(address account, MintParams memory mintParams) external returns(uint256, uint256);

    function tokenPledge(uint256 tokenID) external view returns(uint256);

    function logicBurn(BurnParams memory burnParams) external;
}

interface IMStaker {
    function setProfitDurSeconds(uint256 value) external;

    function stake(address account, uint256 amount) external;

    function unstake(address account, uint256 amount) external returns(uint256);

    function incPledge(uint256 amount) external;

    function decPledge(uint256 amount) external;

    function setProfitRate(uint256 profitRate) external;

    function queryStake(address account) external view returns(Stake memory);

    function takeProfit(address account, uint256 profit)  external;

    function exchange(address account, uint256 amount, bool isFilToMFil) external;

    function swap(address account, uint256 amount, bool isFilToMFil) external;
}

interface IConfig {
    function mdaoAddress() external view returns (address);

    function mstakerAddress() external view returns (address);

    function mnftAddress() external view returns (address);

    function mfilAddress() external view returns (address);

    function encodeAddress() external view returns (address);

    function logicAddress() external view returns (address);

    function fil2MfilAccount() external view returns (address);

    function mfil2FilAccount() external view returns (address);

    function profitAccount() external view returns (address);
}

interface IMAccount {
    function withdraw(address account, uint256 amount) external;
}

