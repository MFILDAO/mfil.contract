// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MIntf.sol";
import "./MBase.sol";

contract MStaker is MBase, IMStaker {
    uint256 constant RATE_PRECISION = 1000;
    uint256 constant RATE_BITS = 10;

    error TransferFailed();

    ProfitRate[] private _profitRates;

    uint256 private _profitDurSeconds;

    uint256 private _totalPledge;

    uint256 private _totalStake;

    uint256 private _profitFactor;

    mapping(address => Stake) private _stakes;

    constructor(address configContract_) MBase(configContract_) {
        _profitDurSeconds = 86400;
        _profitRates.push(ProfitRate({rate: 0, date: 0}));
    }

    function _calcProfitFactor(ProfitRate memory stakeRate)
        internal
        view
        returns (uint256)
    {
        uint256 d = _daysOf(block.timestamp) - _daysOf(stakeRate.date);
        return _profitFactor + ((d * stakeRate.rate) << RATE_BITS) / 365;
    }

    function _daysOf(uint256 t) internal view returns (uint256) {
        return t / _profitDurSeconds;
    }

    function _caclStakeProfit(
        uint256 amount,
        uint256 startFactor,
        uint256 currentFactor
    ) internal pure returns (uint256) {
        if (amount > 0) {
            return
                ((amount * (currentFactor - startFactor)) / RATE_PRECISION) >>
                RATE_BITS;
        }
        return 0;
    }

    function _newStake(Stake memory oldStake, uint256 amount)
        internal
        view
        returns (Stake memory)
    {
        ProfitRate memory profitRate = currentProfitRate();
        require(
            block.timestamp > profitRate.date,
            "current block timestamp is invalid"
        );
        uint256 currentFactor = _calcProfitFactor(profitRate);
        uint256 profit = oldStake.profit +
            _caclStakeProfit(
                oldStake.amount,
                oldStake.profitStartFactor,
                currentFactor
            );
        return
            Stake({
                date: block.timestamp,
                profit: profit,
                amount: amount,
                profitStartFactor: currentFactor
            });
    }

    function profitDurSeconds() external view returns (uint256) {
        return _profitDurSeconds;
    }

    function setProfitDurSeconds(uint256 value) external onlyLogic() {
        require(value > 0, "profitDurSeconds must be greater than zero");
        _profitFactor = _calcProfitFactor(currentProfitRate());
        _profitDurSeconds = value;
    }

    function queryProfitRate(uint256 idx)
        external
        view
        returns (ProfitRate memory)
    {
        require(_profitRates.length > idx, "index is invalid");
        return _profitRates[idx];
    }

    function profitRatesSize() external view returns (uint256) {
        return _profitRates.length;
    }

    function currentProfitRate() public view returns (ProfitRate memory) {
        return _profitRates[_profitRates.length - 1];
    }

    function setProfitRate(uint256 profitRate) external onlyLogic() {
        _profitFactor = _calcProfitFactor(currentProfitRate());
        _profitRates.push(
            ProfitRate({rate: profitRate, date: block.timestamp})
        );
    }

    function incPledge(uint256 amount) external {
        require(
            _totalPledge + amount > _totalPledge,
            "add pledge amount is not invalid"
        );
        
        _totalPledge += amount;
    }

    function decPledge(uint256 amount) external {
        require(
            _totalPledge >= amount + _totalStake,
            "release pledge is over limit"
        );
        _totalPledge -= amount;
    }

    function queryStake(address account) external view returns (Stake memory) {
        return _stakes[account];
    }

    function stake(address account, uint256 amount) external onlyLogic() {
        require(
            amount > 0 && _totalStake + amount <= _totalPledge,
            "stake amount is over limit"
        );

        IERC20(configContract().mfilAddress()).transferFrom(
            account,
            address(this),
            amount
        );

        Stake memory st = _stakes[account];
        _stakes[account] = _newStake(st, st.amount + amount);

        _totalStake += amount;
    }

    function unstake(address account, uint256 amount)
        external
        onlyLogic()
        returns (uint256)
    {
        Stake memory st = _stakes[account];
        require(
            st.amount >= amount && amount > 0,
            "stake account is insufficient"
        );
        _stakes[account] = _newStake(st, st.amount - amount);
        IERC20(configContract().mfilAddress()).transfer(account, amount);
        _totalStake -= amount;

        return amount;
    }

    function takeProfit(address account, uint256 profit) external onlyLogic() {
        require(profit > 0, "take profit is invalid");
        Stake memory st = _stakes[account];
        st = _newStake(st, st.amount);
        require(st.profit >= profit, "profit balance is not enough");
        st.profit -= profit;
        _stakes[account] = st;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _stakes[account].amount;
    }

    function profitOf(address account) external view returns (uint256) {
        Stake memory st = _stakes[account];
        // console.log(block.timestamp);
        uint256 currentFactor = _calcProfitFactor(currentProfitRate());
        return
            st.profit +
            _caclStakeProfit(st.amount, st.profitStartFactor, currentFactor);
    }

    function exchange(
        address account,
        uint256 amount,
        bool isFilToMFil
    ) external onlyLogic() {
        if (isFilToMFil) {
            IERC20(configContract().mfilAddress()).transfer(account, amount);
        } else {
            IERC20(configContract().mfilAddress()).transferFrom(
                account,
                address(this),
                amount
            );
        }
    }

    function swap(
        address account,
        uint256 amount,
        bool isFilToMFil
    ) external onlyLogic() {
        if (isFilToMFil) {
            IERC20(configContract().mfilAddress()).transfer(account, amount);
        } else {
            IERC20(configContract().mfilAddress()).transferFrom(
                account,
                address(this),
                amount
            );
        }
    }

    function totalPledge() public view returns (uint256) {
        return _totalPledge;
    }

    function totalStake() public view returns (uint256) {
        return _totalStake;
    }
}
