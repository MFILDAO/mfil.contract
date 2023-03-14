// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Counters.sol";

contract MNft is ERC721, Ownable {

    using Counters for Counters.Counter;

    string private _baseTokenURI;
    Counters.Counter internal _tokenId;

    constructor() ERC721("MNft", "MNFT") {}

    function setBaseURI(string calldata newBaseTokenURI) public onlyOwner {
        _baseTokenURI = newBaseTokenURI;
    }

    function mintNft(address to) public onlyOwner returns(uint256) {
        _tokenId.increment();

        _safeMint(to, _tokenId.current());

        return _tokenId.current();
    }

    function burnNft(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}
