// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

import {extractUint8, extractUint16, extractUint256} from "./Utils.sol";

// //////////////////////////////////////////////////////////////
// WORMHOLE STRUCTS
// //////////////////////////////////////////////////////////////

struct Provider {
    uint16 chainId;
    uint16 governanceChainId;
    bytes32 governanceContract;
}

struct GuardianSet {
    address[] keys;
    uint32 expirationTime;
}

struct Signature {
    bytes32 r;
    bytes32 s;
    uint8 v;
    uint8 guardianIndex;
}

struct WormholeVm {
    uint8 version;
    uint32 timestamp;
    uint32 nonce;
    uint16 emitterChainId;
    bytes32 emitterAddress;
    uint64 sequence;
    uint8 consistencyLevel;
    bytes payload;

    uint32 guardianSetIndex;
    Signature[] signatures;

    bytes32 hash;
}

// //////////////////////////////////////////////////////////////
// LOCAL ENUMS / STRUCTS
// //////////////////////////////////////////////////////////////

enum MessageType {
    TRANSFER
    // TRANSFER_WITH_PAYLOAD
}

struct TransferMessage {
    MessageType messageType;
    uint16 senderChainId;
    bytes32 senderToken;
    bytes32 receiver;
    uint16 receiverChainId;
    bytes32 receiverToken;
    uint256 amount;
    uint256 fee;
}

using { serialize } for TransferMessage global;

// //////////////////////////////////////////////////////////////
// LOCAL STRUCT ENCODING / DECODING
// //////////////////////////////////////////////////////////////

function toTransferMessage(bytes memory message)
    pure
    returns (TransferMessage memory transferMessage)
{
    uint256 index;
    transferMessage.messageType = MessageType(extractUint8(message, index));
    index += 1;
    transferMessage.senderChainId = extractUint16(message, index);
    index += 2;
    transferMessage.senderToken = bytes32(extractUint256(message, index));
    index += 32;
    transferMessage.receiver = bytes32(extractUint256(message, index));
    index += 32;
    transferMessage.receiverChainId = extractUint16(message, index);
    index += 2;
    transferMessage.receiverToken = bytes32(extractUint256(message, index));
    index += 32;
    transferMessage.amount = extractUint256(message, index);
    index += 32;
    transferMessage.fee = extractUint256(message, index);
}

function serialize(TransferMessage memory transferMessage) pure returns (bytes memory) {
    return abi.encodePacked(
        transferMessage.messageType,
        transferMessage.senderChainId,
        transferMessage.senderToken,
        transferMessage.receiver,
        transferMessage.receiverChainId,
        transferMessage.receiverToken,
        transferMessage.amount,
        transferMessage.fee
    );
}
