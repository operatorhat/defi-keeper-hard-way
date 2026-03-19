// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/KeeperTrigger.sol";

contract KeeperTriggerTest is Test {
    KeeperTrigger keeper;

    function setUp() public {
        keeper = new KeeperTrigger(1 hours);
    }

    function test_checkUpkeep_ReturnsFalse_BeforeInterval() public {
        (bool upkeepNeeded, bytes memory performData) = keeper.checkUpkeep("");
        assertFalse(upkeepNeeded);
        assertEq(performData, "");
    }

    function test_checkUpkeep_ReturnsFalse_OneSecondShort() public {
        vm.warp(block.timestamp + 3599);
        (bool upkeepNeeded, ) = keeper.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_checkUpkeep_ReturnsTrue_AtExactInterval() public {
        vm.warp(block.timestamp + 3600);
        (bool upkeepNeeded, bytes memory performData) = keeper.checkUpkeep("");
        assertTrue(upkeepNeeded);
        assertEq(performData, "");
    }

    function test_checkUpkeep_ReturnsTrue_AfterInterval() public {
        vm.warp(block.timestamp + 7200);
        (bool upkeepNeeded, ) = keeper.checkUpkeep("");
        assertTrue(upkeepNeeded);
    }

    function test_performUpkeep_ResetsLastTimestamp() public {
        vm.warp(block.timestamp + 7200);
        keeper.performUpkeep("");
        assertEq(keeper.lastTimestamp(), block.timestamp);
    }

    function test_performUpkeep_EmitsUpkeepPerformed() public {
        vm.warp(block.timestamp + 7200);
        vm.expectEmit(true, true, false, true);
        emit KeeperTrigger.UpkeepPerformed(block.timestamp);
        keeper.performUpkeep("");
    }

    function test_performUpkeep_RevertsWhenNotNeeded_Immediate() public {
        vm.expectRevert(KeeperTrigger.UpkeepNotNeeded.selector);
        keeper.performUpkeep("");
    }

    function test_performUpkeep_RevertsWhenNotNeeded_OneSecondShort() public {
        vm.warp(block.timestamp + 3599);
        vm.expectRevert(KeeperTrigger.UpkeepNotNeeded.selector);
        keeper.performUpkeep("");
    }

    function test_performUpkeep_SubsequentCallRevertsUntilNextInterval() public {
        vm.warp(block.timestamp + 7200);
        keeper.performUpkeep("");
        vm.expectRevert(KeeperTrigger.UpkeepNotNeeded.selector);
        keeper.performUpkeep("");
    }

    function test_checkUpkeep_ReturnsFalse_AfterSuccessfulPerform() public {
        vm.warp(block.timestamp + 7200);
        keeper.performUpkeep("");
        (bool upkeepNeeded, ) = keeper.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function test_constructor_SetsImmutableInterval() public {
        KeeperTrigger newKeeper = new KeeperTrigger(42);
        assertEq(newKeeper.INTERVAL(), 42);
    }

    function test_constructor_SetsLastTimestampToDeployBlock() public {
        vm.warp(1234567890);
        KeeperTrigger newKeeper = new KeeperTrigger(1 hours);
        assertEq(newKeeper.lastTimestamp(), block.timestamp);
    }

    function test_constructor_RevertsOnZeroInterval() public {
        vm.expectRevert("KeeperTrigger: interval cannot be zero");
        new KeeperTrigger(0);
    }

    function test_performUpkeep_AnyCallerCanTrigger() public {
        vm.warp(block.timestamp + 7200);
        address prankAddress = address(0x1234);
        vm.prank(prankAddress);
        keeper.performUpkeep("");
        assertEq(keeper.lastTimestamp(), block.timestamp);
    }

    function test_performUpkeep_PerformDataParamIgnored() public {
        vm.warp(block.timestamp + 7200);
        keeper.performUpkeep(hex"deadbeef");
        assertEq(keeper.lastTimestamp(), block.timestamp);
    }
}
