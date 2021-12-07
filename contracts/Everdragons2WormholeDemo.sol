// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./WormholeERC721.sol";

/// @custom:security-contact security@ndujalabs.com
contract Everdragons2WormholeDemo is ERC721, ERC721Burnable, WormholeERC721 {
    constructor() ERC721("Everdragons2Wormhole Demo", "ED2d") {}

    function _baseURI() internal pure override returns (string memory) {
        return "https://everdragons2.com/metadata/ed2/";
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    // OpenSea contractURI()
    function contractURI() public view returns (string memory) {
        return _baseURI();
    }

    // Initiate a transfer over Wormhole
    function wormholeTransfer(uint256 tokenID, uint16 recipientChain, bytes32 recipient, uint32 nonce) public payable returns (uint64 sequence) {
        require(_isApprovedOrOwner(_msgSender(), tokenID), "ERC721: transfer caller is not owner nor approved");
        burn(tokenID);
        return _wormholeTransfer(tokenID, recipientChain, recipient, nonce);
    }

    // Complete a transfer from Wormhole
    function wormholeCompleteTransfer(bytes memory encodedVm) public {
        (address to, uint256 tokenId) = _wormholeCompleteTransfer(encodedVm);
        _safeMint(to, tokenId);
    }

//    function wormholeGetContract(uint16 chainId) public {
//        return _wormholeGetContract(chainId);
//    }
//
//    function wormholeGetAllContracts() public {
//        return _wormholeGetAllContracts();
//    }
}
