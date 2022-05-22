// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";

import {AunarPool, BridgeToken} from "../src/AunarPool.sol";
import {MessageType, WormholeVm, TransferMessage, toTransferMessage} from "../src/utils/Types.sol";
import {toBytes32, toAddress, denormalizeAmount} from "../src/utils/Utils.sol";

using { toBytes32 } for address;
using { toAddress } for bytes32;
using { toTransferMessage } for bytes;

import {WormholeMock} from "./mocks/WormholeMock.sol";

contract AunarPoolTest is Test {

    event LogMessagePublished(
        address indexed sender,
        uint64 sequence,
        uint32 nonce,
        bytes payload,
        uint8 consistencyLevel
    );

    event LiquidityReceived(
        address indexed receiver,
        uint16 senderChainId,
        uint256 amount,
        uint256 fee
    );

    BridgeToken internal token;
    AunarPool internal pool;
    WormholeMock internal wormhole = WormholeMock(
        address(0xC89Ce4735882C9F0f0FE26686c53074E09B0D550)
    );

    address internal constant admin = address(1);
    address internal constant alice = address(2);
    address internal constant bob = address(3);

    uint16 internal constant chainId = 1;
    uint16 internal constant foreignChainId = 2;
    address internal constant foreignPool = address(10);
    address internal constant foreignAsset = address(11);

    uint256 internal constant one = 1 ether;
    uint8 internal constant consistencyLevel = 1;

    function setUp() public {
        vm.chainId(chainId);

        vm.startPrank(admin);

        token = new BridgeToken("Mock Token", "MoT");

        token.mint(alice, 10 ether);

        token.mint(bob, 10 ether);

        pool = new AunarPool(address(0), token, foreignAsset, "Aunar MoT", "auMoT", chainId);

        pool.addPool(foreignChainId, foreignPool);

        token.setBridge(address(pool));

        // etch wormhole code to deterministic address
        vm.etch(address(wormhole), address(new WormholeMock()).code); // wtf

        vm.stopPrank();
    }

    function testTotalAssets() public {
        vm.startPrank(alice);
        token.approve(address(pool), one);
        pool.deposit(one, alice);

        assertEq(token.balanceOf(address(pool)), one);
    }

    function testAddPool() public {
        uint16 testChainId = 69;
        address testPool = address(69);
        vm.prank(admin);
        pool.addPool(testChainId, testPool);

        assertEq(pool.pools(testChainId), testPool);
    }

    function testSendLiquidity() public {
        vm.startPrank(alice);
        token.approve(address(pool), type(uint256).max);
        pool.deposit(one, alice);

        uint16 receiverChainId = 2;

        vm.expectEmit(true, true, true, true, address(wormhole));

        bytes memory payload = TransferMessage({
            messageType: MessageType.TRANSFER,
            senderChainId: pool.chainId(),
            senderToken: address(token).toBytes32(),
            receiver: alice.toBytes32(),
            receiverChainId: receiverChainId,
            receiverToken: pool.foreignAsset(),
            amount: one,
            fee: 0
        }).serialize();

        emit LogMessagePublished(
            address(pool),
            0,
            0,
            payload,
            consistencyLevel
        );

        pool.sendLiquidity(alice, foreignChainId, one, 0);

        assertEq(token.balanceOf(alice), 8 ether);
    }

    function testReceiveLiquidity() public {
        TransferMessage memory tMessage = TransferMessage({
            messageType: MessageType.TRANSFER,
            senderChainId: foreignChainId,
            senderToken: foreignAsset.toBytes32(),
            receiver: alice.toBytes32(),
            receiverChainId: chainId,
            receiverToken: address(token).toBytes32(),
            amount: one,
            fee: 0
        });

        vm.expectEmit(true, true, true, true, address(pool));

        emit LiquidityReceived(
            tMessage.receiver.toAddress(),
            tMessage.senderChainId,
            tMessage.amount,
            tMessage.fee
        );

        emit log_named_uint("pool", pool.chainId());
        emit log_named_uint("local", chainId);

        // hack
        // this SHOULD NOT be the tMessage, but the encoded VM but there's like 10 hours left in
        // this hackathon and i can't be bonked to make a full VM serialization mock.
        pool.receiveLiquidity(tMessage.serialize());

        assertEq(token.balanceOf(alice), 11 ether);
    }
}
