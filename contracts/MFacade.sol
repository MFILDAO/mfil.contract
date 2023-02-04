// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./MIntf.sol";
import "./MBase.sol";

contract MFacade is MBase {
    event BurnNftEvent(
        address account,
        uint256 minerID,
        uint256 tokenID,
        uint256 pledge
    );

    event MintedNftEvent(
        address account,
        uint256 tokenID,
        uint256 minerID,
        uint256 pledgeAmount,
        uint256 expireDate,
        string uri,
        uint256 txID
    );

    event ProfitRateChangedEvent(address account, uint256 newRate);

    event ProfitDurSecondsChangedEvent(address account, uint256 value);

    event ExchangeInEvent(
        address account,
        uint256 amount,
        string filAddr,
        uint256 txID
    );

    event ExchangeOutEvent(
        address account,
        uint256 amount,
        string filAddr,
        uint256 txID
    );

    event SwapIn(
        address account,
        uint256 amount,
        string filAddr,
        uint256 txID
    );

    event SwapOut(
        address account,
        uint256 amount,
        string filAddr,
        uint256 txID
    );

    event StakeEvent(address account, uint256 amount, uint256 txID);

    event UnstakeEvent(address account, uint256 amount, uint256 txID);

    event TakeProfitEvent(
        address account,
        uint256 profit,
        string filAddr,
        uint256 txID
    );

    enum ActionType {
        MintNft,
        ExchangeIn,
        ExchangeOut,
        Stake,
        Unstake,
        TakeProfit,
        BurnNft
    }

    mapping(address => mapping(ActionType => uint256)) private _txIds;

    constructor(address configContract_) MBase(configContract_) {}

    function _checkSign(
        string memory message,
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        address encodeAddress
    ) internal pure {
        bytes32 msgHash = keccak256(bytes(message));
        require(hash == msgHash, "inconsistent parameter hash values");
        require(
            ECDSA.recover(
                keccak256(
                    abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
                ),
                v,
                r,
                s
            ) == encodeAddress,
            "insufficient permissions"
        );
    }

    function _checkAndUpdateTxId(ActionType actionType, uint256 txId) internal {
        require(
            txId == _txIds[_msgSender()][actionType] + 1,
            "txId is invalid"
        );
        _txIds[_msgSender()][actionType]++;
    }

    function currentTxId(address account, ActionType actionType)
        public
        view
        returns (uint256)
    {
        return _txIds[account][actionType];
    }

    function setProfitDurSeconds(uint256 value)
        external
        onlyAddrOrOwner(configContract().mdaoAddress())
    {
        IMStaker(configContract().mstakerAddress()).setProfitDurSeconds(value);
        emit ProfitDurSecondsChangedEvent(_msgSender(), value);
    }

    function setProfitRate(uint256 profitRate)
        external
        onlyAddrOrOwner(configContract().mdaoAddress())
    {
        IMStaker(configContract().mstakerAddress()).setProfitRate(profitRate);
        emit ProfitRateChangedEvent(_msgSender(), profitRate);
    }

    function mintNft(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        MintParams calldata inputParams
    ) public returns (uint256) {
        require(
            block.timestamp < inputParams.expireDate,
            "transaction expired"
        );
        require(inputParams.account == _msgSender(), "invalid request");
        _checkAndUpdateTxId(ActionType.MintNft, inputParams.txID);

        string memory message = string(
            abi.encodePacked(
                "action=mintnft",
                "txid=",
                Strings.toString(inputParams.txID),
                "tokenID=",
                Strings.toString(inputParams.tokenID),
                "minerID=",
                Strings.toString(inputParams.minerID),
                "pledgeAMount=",
                Strings.toString(inputParams.pledgeAmount),
                "expireDate=",
                Strings.toString(inputParams.expireDate),
                "minerAccount=",
                Strings.toHexString(_msgSender()),
                "uri=",
                inputParams.uri
            )
        );

        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        uint256 tokenID;
        uint256 pledgeAmount;
        (tokenID, pledgeAmount) = getMNftContract().logicMint(
            _msgSender(),
            inputParams
        );

        if (pledgeAmount > 0) {
            IMStaker(config.mstakerAddress()).incPledge(
                inputParams.pledgeAmount
            );
            getMFilContract().logicMint(
                config.mstakerAddress(),
                inputParams.pledgeAmount
            );
        }

        emit MintedNftEvent(
            _msgSender(),
            tokenID,
            inputParams.minerID,
            inputParams.pledgeAmount,
            inputParams.expireDate,
            inputParams.uri,
            inputParams.txID
        );

        return tokenID;
    }

    function burnNft(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        BurnParams calldata inputParams
    ) public {
        require(inputParams.account == _msgSender(), "permision denied");
        _checkAndUpdateTxId(ActionType.BurnNft, inputParams.txID);

        string memory message = string(
            abi.encodePacked(
                "action=burnnft",
                "txid=",
                Strings.toString(inputParams.txID),
                "account=",
                Strings.toHexString(_msgSender()),
                "minerID=",
                Strings.toString(inputParams.minerID),
                "tokenID=",
                Strings.toString(inputParams.tokenID)
            )
        );

        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        IMNft nft = getMNftContract();
        uint256 pledge = nft.tokenPledge(inputParams.tokenID);
        require(pledge > 0, "token is invalid");

        getMFilContract().logicBurn(_msgSender(), pledge);

        nft.logicBurn(inputParams);

        emit BurnNftEvent(
            _msgSender(),
            inputParams.minerID,
            inputParams.tokenID,
            pledge
        );
    }

    function _exchange(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool isFilToMFil,
        ExchangeParams memory inputParams
    ) internal {
        _checkAndUpdateTxId(
            isFilToMFil ? ActionType.ExchangeIn : ActionType.ExchangeOut,
            inputParams.txID
        );
        require(inputParams.account == _msgSender(), "permision denied");

        string memory message = string(
            abi.encodePacked(
                "action=",
                isFilToMFil ? "exchangeIn" : "exchangeOut",
                "txid=",
                Strings.toString(inputParams.txID),
                "account=",
                Strings.toHexString(inputParams.account),
                "amount=",
                Strings.toString(inputParams.amount),
                "filAddr=",
                inputParams.filAddr
            )
        );

        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        IMStaker(config.mstakerAddress()).exchange(
            inputParams.account,
            inputParams.amount,
            isFilToMFil
        );
    }

    function _swap(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bool isFilToMFil,
        ExchangeParams memory inputParams
    ) internal {
        _checkAndUpdateTxId(
            isFilToMFil ? ActionType.ExchangeIn : ActionType.ExchangeOut,
            inputParams.txID
        );
        require(inputParams.account == _msgSender(), "permision denied");

        string memory message = string(
            abi.encodePacked(
                "action=",
                isFilToMFil ? "exchangeIn" : "exchangeOut",
                "txid=",
                Strings.toString(inputParams.txID),
                "account=",
                Strings.toHexString(inputParams.account),
                "amount=",
                Strings.toString(inputParams.amount)
            )
        );

        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        if (isFilToMFil) {
            IMStaker(config.mstakerAddress()).swap(inputParams.account, msg.value, true); 

            (bool success,) = address(config.fil2MfilAccount()).call{value: msg.value}("");

            require(success, "receive fil failed");
        } else {
            IMStaker(config.mstakerAddress()).swap(inputParams.account, inputParams.amount, false);

            IMAccount mfil2FilAccount =  IMAccount(config.mfil2FilAccount());
            mfil2FilAccount.withdraw(_msgSender(), inputParams.amount);
        }
    }

    function swapIn(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        ExchangeParams calldata inputParams
    ) public payable {
        _swap(hash, v, r, s, true, inputParams);
        emit SwapIn(
            inputParams.account,
            inputParams.amount,
            inputParams.filAddr,
            inputParams.txID
        );
    }

    function swapOut(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        ExchangeParams calldata inputParams
    ) public {
        _swap(hash, v, r, s, false, inputParams);
        emit SwapOut(
            inputParams.account,
            inputParams.amount,
            inputParams.filAddr,
            inputParams.txID
        );
    }

    function exchangeIn(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        ExchangeParams calldata inputParams
    ) public {
        _exchange(hash, v, r, s, true, inputParams);
        emit ExchangeInEvent(
            inputParams.account,
            inputParams.amount,
            inputParams.filAddr,
            inputParams.txID
        );
    }

    function exchangeOut(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        ExchangeParams calldata inputParams
    ) public {
        _exchange(hash, v, r, s, false, inputParams);
        emit ExchangeOutEvent(
            inputParams.account,
            inputParams.amount,
            inputParams.filAddr,
            inputParams.txID
        );
    }

    function stake(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        StakeParams calldata inputParams
    ) public {
        require(inputParams.account == _msgSender(), "permision denied");
        _checkAndUpdateTxId(ActionType.Stake, inputParams.txID);

        string memory message = string(
            abi.encodePacked(
                "action=stake",
                "txid=",
                Strings.toString(inputParams.txID),
                "account=",
                Strings.toHexString(inputParams.account),
                "amount=",
                Strings.toString(inputParams.amount)
            )
        );

        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        IMStaker(config.mstakerAddress()).stake(
            _msgSender(),
            inputParams.amount
        );

        emit StakeEvent(_msgSender(), inputParams.amount, inputParams.txID);
    }

    function unstake(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        UnstakeParams calldata inputParams
    ) public {
        require(inputParams.account == _msgSender(), "permision denied");
        _checkAndUpdateTxId(ActionType.Unstake, inputParams.txID);

        string memory message = string(
            abi.encodePacked(
                "action=unstake",
                "txid=",
                Strings.toString(inputParams.txID),
                "account=",
                Strings.toHexString(inputParams.account),
                "amount=",
                Strings.toString(inputParams.amount)
            )
        );

        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        IMStaker staker = IMStaker(config.mstakerAddress());
        staker.unstake(_msgSender(), inputParams.amount);

        emit UnstakeEvent(_msgSender(), inputParams.amount, inputParams.txID);
    }

    function takeProfit(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s,
        TakeProfitParams calldata inputParams
    ) public {
        require(inputParams.account == _msgSender(), "permision denied");
        _checkAndUpdateTxId(ActionType.TakeProfit, inputParams.txID);

        string memory message = string(
            abi.encodePacked(
                "action=takeprofit",
                "txid=",
                Strings.toString(inputParams.txID),
                "account=",
                Strings.toHexString(inputParams.account),
                "profit=",
                Strings.toString(inputParams.profit),
                "filAddr=",
                inputParams.filAddr
            )
        );
        IConfig config = configContract();
        _checkSign(message, hash, v, r, s, config.encodeAddress());

        IMStaker staker = IMStaker(config.mstakerAddress());
        staker.takeProfit(_msgSender(), inputParams.profit);

        IMAccount profitAccount =  IMAccount(config.profitAccount());
        profitAccount.withdraw(_msgSender(), inputParams.profit);

        emit TakeProfitEvent(
            _msgSender(),
            inputParams.profit,
            inputParams.filAddr,
            inputParams.txID
        );
    }
}
