// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";


import "@openzeppelin/contracts/access/Ownable.sol";


import "./MIntf.sol";

import "./MBase.sol";

contract MNft is
    MBase,
    IMNft,
    ERC721Enumerable,
    ERC721URIStorage
{
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(uint256 => MinerToken) private _minerTokens;
    mapping(uint256 => uint256) private _minerTokenIds;

    constructor(
        address configContract_,
        string memory name_,
        string memory symbol_) ERC721(name_, symbol_) MBase(configContract_) {
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return _minerTokens[tokenId].tokenUri;
    }

    function logicMint(address account, MintParams calldata mintParams) external 
        onlyLogic() 
        returns(uint256, uint256) {

        require(mintParams.pledgeAmount > 0, "input params pledgeAmount is invalid");
        require(mintParams.minerID != 0, "input params minerID is invalid");
        require(mintParams.expireDate > block.timestamp, "input params expireDate is invalid");

        if (mintParams.tokenID != 0) {
            MinerToken memory token = _minerTokens[mintParams.tokenID];
            require(token.minerID == mintParams.minerID, "miner id is invalid");
            require(mintParams.expireDate >= token.expireDate, "expire date is invalid");
            require(mintParams.pledgeAmount >= token.pledgeAmount, "pledge amount is invalid");
            uint256 newPledgeAmount = mintParams.pledgeAmount - token.pledgeAmount;
            _minerTokens[mintParams.tokenID] = MinerToken({
                minerID: mintParams.minerID,
                expireDate: mintParams.expireDate,
                pledgeAmount: mintParams.pledgeAmount,
                tokenUri: mintParams.uri
            });
            return (mintParams.tokenID, newPledgeAmount);
        } else {
            require(_minerTokenIds[mintParams.minerID] == 0, "input params minerID have minted");
            _tokenIds.increment();

            uint256 newItemId = _tokenIds.current();
            _minerTokenIds[mintParams.minerID] = newItemId;
            _minerTokens[newItemId] = MinerToken({
                minerID: mintParams.minerID,
                expireDate: mintParams.expireDate,
                pledgeAmount: mintParams.pledgeAmount,
                tokenUri: mintParams.uri
            });

            _safeMint(account, newItemId);
            return (newItemId, mintParams.pledgeAmount);
        }
    }

    function logicBurn(BurnParams memory burnParams) external 
        onlyLogic() {
        require(burnParams.minerID != 0, "input params is invalid");
        require(burnParams.minerID == _minerTokens[burnParams.tokenID].minerID, "input params is invalid");
        _burn(burnParams.tokenID);
        delete _minerTokens[burnParams.tokenID];
    }

    function minerToken(uint256 tokenId) external view returns(MinerToken memory) {
        return _minerTokens[tokenId];
    }

    function tokenPledge(uint256 tokenID) external view returns(uint256) {
        return _minerTokens[tokenID].pledgeAmount;
    }
}