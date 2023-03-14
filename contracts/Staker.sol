// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/utils/cryptography/SignatureChecker.sol";
import "openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/access/AccessControl.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/utils/StorageSlot.sol";

import "./MFil.sol";
import "./MNft.sol";

struct StakeNode {
    uint256 minerID;
    uint256 amount;
    uint256 expireDate;
}

struct MinerRewards {
    uint256 stakeNodeId;
    uint256 amount;
    uint256 unrewards;
}

abstract contract DataLayout {
    mapping(uint256 => StakeNode) internal _stakeNodes;
    mapping(address => Counters.Counter) internal _nonces;
}

contract Staker is MFil, DataLayout, AccessControl, Initializable {
    using Counters for Counters.Counter;
    using SignatureChecker for address;
    using ECDSA for bytes32;
    using StorageSlot for bytes32;

    event StakeNodeInfo(address, uint256, uint256, uint256);
    event UnStakeNodeInfo(uint256 tokenId);
    event Swap(address, uint256);
    event DistributeRewards(address, uint256);
    event DistributeUnRewards(address, uint256);

    bytes32 constant public MANAGE_ROLE = keccak256("MANAGE_ROLE");

    bytes32 constant public DAO_ROLE = keccak256("DAO_ROLE");

    bytes32 constant public REWARD_ROLE = keccak256("REWARD_ROLE");

    uint256 constant internal TOTAL_BASIS_POINTS = 10000;

    bytes32 internal constant TOTAL_FIL_POSITION = keccak256("mfil.dao.total_fil");

    bytes32 internal constant MINER_REWARD_RATIO_POSITION = keccak256("mfil.dao.miner_reward_ratio");

    bytes32 internal constant DAO_REWARD_RATIO_POSITION = keccak256("mfil.dao.dao_reward_ratio");

    bytes32 internal constant USER_REWARD_ADDRESS_POSITION = keccak256("mfil.dao.user_reward_address");

    bytes32 internal constant DAO_REWARD_ADDRESS_POSITION = keccak256("mfil.dao.dao_reward_address");

    bytes32 internal constant SYS_SIGNER_ADDRESS_POSITION = keccak256("mfil.dao.sys_signer_address");

    bytes32 internal constant USER_SWAP_POSITION = keccak256("mfil.dao.user_swap_address");

    bytes32 internal constant MNFT_POSITION = keccak256("mfil.dao.mnft");

    function initialize() 
        public 
        initializer
    {
        _grantRole(MANAGE_ROLE, msg.sender);
        _setRoleAdmin(DAO_ROLE, MANAGE_ROLE);
        _setRoleAdmin(REWARD_ROLE, MANAGE_ROLE);

        MNft _mnft = new MNft();
        MNFT_POSITION.getAddressSlot().value = address(_mnft);
        MINER_REWARD_RATIO_POSITION.getUint256Slot().value = 5000;
        DAO_REWARD_RATIO_POSITION.getUint256Slot().value = 800;
    }

    function stop() public onlyRole(DAO_ROLE) {
        _stop();
    }

    function resume() public onlyRole(DAO_ROLE) {
        _resume();
    }

    function setSigner(address addr) public onlyRole(DAO_ROLE){
        SYS_SIGNER_ADDRESS_POSITION.getAddressSlot().value = addr;
    }

    function signer() public view returns(address){
        return SYS_SIGNER_ADDRESS_POSITION.getAddressSlot().value;
    }

    function setDaoRewards(address addr) public onlyRole(DAO_ROLE){
        DAO_REWARD_ADDRESS_POSITION.getAddressSlot().value = addr;
    }

    function daoRewards() public view returns(address){
        return  DAO_REWARD_ADDRESS_POSITION.getAddressSlot().value;
    }

    function setMinerVault(address addr) public onlyRole(DAO_ROLE){
        USER_SWAP_POSITION.getAddressSlot().value = addr;
    }

    function minerVault() public view returns(address){
        return USER_SWAP_POSITION.getAddressSlot().value;
    }

    function setUserRewards(address addr) public onlyRole(DAO_ROLE){
        USER_REWARD_ADDRESS_POSITION.getAddressSlot().value = addr;
    }

    function userRewards() public view returns(address){
        return USER_REWARD_ADDRESS_POSITION.getAddressSlot().value;
    }

    function mnft() public view returns (address){
        return MNFT_POSITION.getAddressSlot().value;
    }

    function withdraw(address account, uint256 amount) 
        external 
        onlyRole(DAO_ROLE) 
    {
        require(amount <= address(this).balance, "invalid amount");

        (bool success,) = account.call{value: amount}("");
        require(success, "withdraw failed");
    }

    function burnToken(uint256 amount)
        external
        onlyRole(DAO_ROLE)
        returns (uint256 newTotalShares)
    {
        uint256 sharesAmount = getSharesByPooledEth(amount);

        TOTAL_FIL_POSITION.getUint256Slot().value -= amount;
        
        return _burnShares(msg.sender, sharesAmount);
    }

    function setRewardsRatio(uint256 miner, uint256 dao) 
        external 
        onlyRole(DAO_ROLE) 
    {
        require(miner + dao < TOTAL_BASIS_POINTS, "invalid ratio");

        MINER_REWARD_RATIO_POSITION.getUint256Slot().value = miner;

        DAO_REWARD_RATIO_POSITION.getUint256Slot().value = dao;
    }

    function setBaseUrl(string calldata uri) 
        external 
        onlyRole(DAO_ROLE) 
    {
        MNft(mnft()).setBaseURI(uri);
    }

    function currNonce(address addr) public view returns (uint256) {
        return _nonces[addr].current();
    }

    function stakeNodeInfo(uint256 tokenId) public view returns (StakeNode memory) {
        return _stakeNodes[tokenId];
    }
    modifier checkNonce(uint256 nonce) {
        require(nonce == currNonce(msg.sender) + 1, "nonce error");
        _;
        _nextNonce(msg.sender);
    }

    function unStakeNode(uint256 tokenId)
        external
        onlyRole(DAO_ROLE)
    {
        uint256 nodeAmount = _stakeNodes[tokenId].amount;
        uint256 sharesAmount = getSharesByPooledEth(nodeAmount);
        
        _burnShares(msg.sender, sharesAmount);

        TOTAL_FIL_POSITION.getUint256Slot().value -= nodeAmount;

        MNft(mnft()).burnNft(tokenId);

        delete _stakeNodes[tokenId];

        emit UnStakeNodeInfo(tokenId);
    }

    function stakeNode(StakeNode calldata params, uint256 nonce, bytes memory signature) 
        public checkNonce(nonce) returns (uint256) 
    {
        require(params.amount > 0, "INVALID_AMOUNT");
        require(params.expireDate > block.timestamp, "INVALID_EXPIRE_TIME");

        bytes32 msgHash = keccak256(
            abi.encode(nonce, msg.sender, params.minerID, params.amount, params.expireDate)
        ).toEthSignedMessageHash();

        _checkSign(msgHash, signature);

        uint256 sharesAmount = getSharesByPooledEth(params.amount);
        if (sharesAmount == 0) {
            sharesAmount = params.amount;
        }

        _mintShares(msg.sender, sharesAmount);

        TOTAL_FIL_POSITION.getUint256Slot().value += params.amount;

        // mint node nft
        uint256 tokenId = MNft(mnft()).mintNft(msg.sender);

        _stakeNodes[tokenId] = params;

        emit StakeNodeInfo(msg.sender, nonce, sharesAmount, tokenId);

        return tokenId;
    }

    function swap() public payable {
        uint256 amount = msg.value;
        address userSwapAddr = USER_SWAP_POSITION.getAddressSlot().value;
        require(userSwapAddr != address(0), "INVALID_VAULT_ADDRESS");
        require(amount > 0 && amount < balanceOf(address(this)), "INVALID_AMOUNT");

        (bool success,) = userSwapAddr.call{value: amount}("");
        require(success, "receive fil failed");

        _transfer(address(this), msg.sender, amount);

        emit Swap(msg.sender, amount);
    }

    function distributeRewards(MinerRewards[] calldata minerRewards) 
        public payable 
        onlyRole(REWARD_ROLE)
    {
        address userRewardAddr = USER_REWARD_ADDRESS_POSITION.getAddressSlot().value;
        address daoRewardAddr =  DAO_REWARD_ADDRESS_POSITION.getAddressSlot().value;
        require(daoRewardAddr!=address(0) && userRewardAddr!=address(0), "invalid dao address or usre fil pool address");
        
        uint256 allAmount = 0;
        uint256 allUnreward = 0;
        uint256 minerRewardRatio = MINER_REWARD_RATIO_POSITION.getUint256Slot().value;
        uint256 daoRewardRatio = DAO_REWARD_RATIO_POSITION.getUint256Slot().value;
        MNft mnft = MNft(mnft());

        for (uint256 i = 0; i < minerRewards.length; i++) {
            require(minerRewards[i].amount > 0, "invalid amount");
            allAmount += minerRewards[i].amount;
            allUnreward += minerRewards[i].unrewards;

            uint256 reward = minerRewards[i].amount * minerRewardRatio / TOTAL_BASIS_POINTS;
            uint256 unrewards = minerRewards[i].unrewards;
            address miner = mnft.ownerOf(minerRewards[i].stakeNodeId);

            if (reward > 0) {
                (bool ok,) = miner.call{value: reward}("");
                require(ok, "TRANSFER_FAILED");
            }

            if (unrewards > 0) {
                (bool ok1,) = miner.call{value: unrewards}("");
                require(ok1, "TRANSFER_FAILED");
            }
            
            emit DistributeRewards(miner, reward);
            emit DistributeUnRewards(miner, unrewards);
        }

        require(msg.value == allAmount + allUnreward, "INVALID_AMOUNT");

        uint256 dao  = allAmount * daoRewardRatio / TOTAL_BASIS_POINTS;
        uint256 user = allAmount * (TOTAL_BASIS_POINTS - minerRewardRatio - daoRewardRatio) / TOTAL_BASIS_POINTS;

        if (dao > 0) {
            (bool ok2,) = daoRewardAddr.call{value: dao}("");
            require(ok2, "TRANSFER_FAILED");
        }

        if (user > 0) {

            (bool ok3,) = userRewardAddr.call{value: user}("");
            require(ok3, "TRANSFER_FAILED");

            TOTAL_FIL_POSITION.getUint256Slot().value += user;
        }

        emit DistributeRewards(daoRewardAddr, dao);
        emit DistributeRewards(userRewardAddr, user);
    }

    function _nextNonce(address addr) internal {
        _nonces[addr].increment();
    }
    
    function _checkSign(bytes32 _hash, bytes memory signature) view internal{
        require(SYS_SIGNER_ADDRESS_POSITION.getAddressSlot().value.isValidSignatureNow(_hash, signature), "INVALID_SIGNATURE");
    }

    function _getTotalPooledEther() internal view virtual override returns (uint256) {
        return TOTAL_FIL_POSITION.getUint256Slot().value;
    }
}