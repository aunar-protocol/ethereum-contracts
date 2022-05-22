// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {BridgeToken} from "./BridgeToken.sol";
import {IWormhole} from "./interfaces/IWormhole.sol";
import {MessageType, WormholeVm, TransferMessage, toTransferMessage} from "./utils/Types.sol";
import {toBytes32, toAddress, denormalizeAmount} from "./utils/Utils.sol";

using { toBytes32 } for address;
using { toAddress } for bytes32;
using { toTransferMessage } for bytes;

error InvalidVm(string reason);
error InvalidEmitter();
error TransactionCompleted();
error InvalidReceiverChain();

contract AunarPool is ERC4626, Owned {

    event LiquiditySent(
        address indexed receiver,
        uint16 receiverChainId,
        uint256 amount,
        uint256 fee
    );

    event LiquidityReceived(
        address indexed receiver,
        uint16 senderChainId,
        uint256 amount,
        uint256 fee
    );

    IWormhole public constant wormhole = IWormhole(
        address(0xC89Ce4735882C9F0f0FE26686c53074E09B0D550)
    );
    uint8 public constant consistencyLevel = 1;

    bytes32 public localAsset;
    bytes32 public foreignAsset;
    uint16 public immutable chainId;
    address public anchorPool;
    mapping(uint16 => address) public pools;
    mapping(bytes32 => bool) public completedTransactions;

    constructor(
        address _anchorPool,
        ERC20 _asset,
        address _foreignAsset,
        string memory _name,
        string memory _symbol,
        uint16 _chainId
    ) ERC4626(_asset, _name, _symbol) Owned(msg.sender) {
        foreignAsset = _foreignAsset.toBytes32();
        anchorPool = _anchorPool;

        localAsset = address(_asset).toBytes32();

        chainId = _chainId;
    }

    function addPool(uint16 poolChainId, address pool) public onlyOwner {
        pools[poolChainId] = pool;
    }

    function totalAssets() public override view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function receiveLiquidity(bytes memory message) public {
        (
            WormholeVm memory vm,
            bool valid,
            string memory reason
        ) = wormhole.parseAndVerifyVM(message);

        if (!valid) revert InvalidVm(reason);

        if (pools[vm.emitterChainId].toBytes32() != vm.emitterAddress) revert InvalidEmitter();

        if (completedTransactions[vm.hash]) revert TransactionCompleted();

        bytes memory serializedTransferMessage = vm.payload;

        TransferMessage memory tMessage = serializedTransferMessage.toTransferMessage();

        if (tMessage.receiverChainId != chainId) revert InvalidReceiverChain();

        address token = tMessage.receiverToken.toAddress();

        completedTransactions[vm.hash] = true;

        BridgeToken(token).mint(address(this), tMessage.amount);

        BridgeToken(token).transfer(tMessage.receiver.toAddress(), tMessage.amount - tMessage.fee);

        emit LiquidityReceived(
            tMessage.receiver.toAddress(),
            tMessage.senderChainId,
            tMessage.amount,
            tMessage.fee
        );
    }

    function sendLiquidity(
        address receiver,
        uint16 receiverChainId,
        uint256 amount,
        uint256 fee
    ) public returns (uint64 sequence) {
        TransferMessage memory transferMessage = TransferMessage(
            MessageType.TRANSFER,
            chainId,
            localAsset,
            receiver.toBytes32(),
            receiverChainId,
            foreignAsset,
            amount,
            fee
        );

        BridgeToken(address(asset)).transferFrom(msg.sender, address(this), amount);

        BridgeToken(address(asset)).burn(address(this), amount);

        sequence = wormhole.publishMessage(0, transferMessage.serialize(), consistencyLevel);

        emit LiquiditySent(receiver, receiverChainId, amount, fee);
    }

}
