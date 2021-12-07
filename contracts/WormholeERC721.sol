// SPDX-License-Identifier: Apache2
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IWormhole.sol";
import "./libraries/BytesLib.sol";

contract NFTStructs {
    struct Transfer {
        // PayloadID uint8 = 1
        // TokenID of the token
        uint256 tokenID;
        // Address of the recipient. Left-zero-padded if shorter than 32 bytes
        bytes32 to;
        // Chain ID of the recipient
        uint16 toChain;
    }
}

contract NFTStorage {
    struct State {

        // Token name
        string name;

        // Token symbol
        string symbol;

        // Mapping from token ID to owner address
        mapping(uint256 => address) owners;

        // Mapping owner address to token count
        mapping(address => uint256) balances;

        // Mapping from token ID to approved address
        mapping(uint256 => address) tokenApprovals;

        // Mapping from token ID to URI
        mapping(uint256 => string) tokenURIs;

        // Mapping from owner to operator approvals
        mapping(address => mapping(address => bool)) operatorApprovals;

        address owner;

        bool initialized;

        address payable wormhole;

        uint16 chainId;

        // Mapping of consumed token transfers
        mapping(bytes32 => bool) completedTransfers;

        // Mapping of bridge contracts on other chains
        mapping(uint16 => bytes32) bridgeImplementations;
    }
}

contract NFTState {
    NFTStorage.State _state;
}

contract NFTGetters is NFTState {
    function isTransferCompleted(bytes32 hash) public view returns (bool) {
        return _state.completedTransfers[hash];
    }

    function bridgeContracts(uint16 chainId_) public view returns (bytes32){
        return _state.bridgeImplementations[chainId_];
    }

    function wormhole() public view returns (IWormhole) {
        return IWormhole(_state.wormhole);
    }

    function chainId() public view returns (uint16) {
        return _state.chainId;
    }
}

contract NFTSetters is NFTState {
    function setOwner(address owner_) internal {
        _state.owner = owner_;
    }

    function setWormhole(address wh) internal {
        _state.wormhole = payable(wh);
    }

    function setChainId(uint16 chainId_) internal {
        _state.chainId = chainId_;
    }

    function setTransferCompleted(bytes32 hash) internal {
        _state.completedTransfers[hash] = true;
    }

    function setBridgeImplementation(uint16 chainId, bytes32 bridgeContract) internal {
        _state.bridgeImplementations[chainId] = bridgeContract;
    }
}


contract WormholeERC721 is Ownable, NFTGetters, NFTSetters {
    using BytesLib for bytes;

    function _wormholeTransfer(uint256 tokenID, uint16 recipientChain, bytes32 recipient, uint32 nonce) internal returns (uint64 sequence) {
        //require(_isApprovedOrOwner(_msgSender(), tokenID), "ERC721: transfer caller is not owner nor approved");
        //TODO require chainID
        sequence = logTransfer(NFTStructs.Transfer({
            tokenID      : tokenID,
            to           : recipient,
            toChain      : recipientChain
        }), msg.value, nonce);
        return sequence;
    }

    function logTransfer(NFTStructs.Transfer memory transfer, uint256 callValue, uint32 nonce) internal returns (uint64 sequence) {
        bytes memory encoded = encodeTransfer(transfer);

        sequence = wormhole().publishMessage{
            value : callValue
        }(nonce, encoded, 15);
    }

    function _wormholeCompleteTransfer(bytes memory encodedVm) internal returns (address to, uint256 tokenId) {
        (IWormhole.VM memory vm, bool valid, string memory reason) = wormhole().parseAndVerifyVM(encodedVm);

        require(valid, reason);
        require(verifyBridgeVM(vm), "invalid emitter");

        NFTStructs.Transfer memory transfer = parseTransfer(vm.payload);

        require(!isTransferCompleted(vm.hash), "transfer already completed");
        setTransferCompleted(vm.hash);

        require(transfer.toChain == chainId(), "invalid target chain");

        // transfer bridged NFT to recipient
        address transferRecipient = address(uint160(uint256(transfer.to)));

        return (transferRecipient, transfer.tokenID);
    }

    function verifyBridgeVM(IWormhole.VM memory vm) internal view returns (bool){
        if (bridgeContracts(vm.emitterChainId) == vm.emitterAddress) {
            return true;
        }

        return false;
    }

    function encodeTransfer(NFTStructs.Transfer memory transfer) internal pure returns (bytes memory encoded) {
        encoded = abi.encodePacked(
            uint8(1),
            transfer.tokenID,
            transfer.to,
            transfer.toChain
        );
    }

    function parseTransfer(bytes memory encoded) internal pure returns (NFTStructs.Transfer memory transfer) {
        uint index = 0;

        uint8 payloadID = encoded.toUint8(index);
        index += 1;

        require(payloadID == 1, "invalid Transfer");

        transfer.tokenID = encoded.toUint256(index);
        index += 32;

        transfer.to = encoded.toBytes32(index);
        index += 32;

        transfer.toChain = encoded.toUint16(index);
        index += 2;

        require(encoded.length == index, "invalid Transfer");
    }

    function registerChain(uint16 chainId_, bytes32 bridgeContract_) internal onlyOwner {
        setBridgeImplementation(chainId_, bridgeContract_);
    }
}
