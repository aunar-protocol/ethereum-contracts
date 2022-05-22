// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.13;

// //////////////////////////////////////////////////////////////
// ADDRESS OPS
// //////////////////////////////////////////////////////////////
function toBytes32(address addr) pure returns (bytes32 padded) {
    assembly { padded := addr }
}

function toAddress(bytes32 padded) pure returns (address addr) {
    assembly { addr := padded }
}

// //////////////////////////////////////////////////////////////
// BYTES OPS
// //////////////////////////////////////////////////////////////
error IndexOutOfBounds(uint256 index);

function extractUint8(bytes memory data, uint256 index) pure returns (uint8 num) {
    if (data.length < index) revert IndexOutOfBounds(index);
    assembly { num := mload(add(add(data, 0x01), index)) }
}

function extractUint16(bytes memory data, uint256 index) pure returns (uint16 num) {
    if (data.length < index) revert IndexOutOfBounds(index);
    assembly { num := mload(add(add(data, 0x02), index)) }
}

function extractUint256(bytes memory data, uint256 index) pure returns (uint256 num) {
    if (data.length < index) revert IndexOutOfBounds(index);
    assembly { num := mload(add(add(data, 0x20), index)) }
}

// //////////////////////////////////////////////////////////////
// UINT256 OPS
// //////////////////////////////////////////////////////////////
function normalizeAmount(uint256 amount, uint8 decimals) pure returns (uint256) {
    return amount / (10 ** decimals);
}

function denormalizeAmount(uint256 amount, uint8 decimals) pure returns (uint256) {
    return amount * (10 ** decimals);
}
