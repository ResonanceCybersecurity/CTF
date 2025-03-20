// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ResonanceStaking} from "../src/ResonanceStaking.sol";
import {ResonancePool} from "../src/ResonancePool.sol";
import {ResonanceToken} from "../src/ResonanceToken.sol";
import {MockToken} from "../mocks/MockToken.sol";

contract AssessmentTest is Test {
    ResonanceToken public resToken; // RES token
    MockToken public usdcToken; // USDC token
    ResonanceStaking public staking; // Staking contract
    ResonancePool public pool; // Pool contract

    // Couple of users to test with
    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // these parameters are arbitrary and can be changed
        uint256 rewards = 10e6; // reward pool is 10 tokens when deployed
        uint256 votes = rewards / 2 + 1; // necesary votes 5 tokens + 1
        uint256 poolLiquidity = 100e6; // liquidity pool has 100 of each token
        uint256 userAmounts = 2e6; // initial users have 2 tokens each

        resToken = new ResonanceToken();
        usdcToken = new MockToken();
        staking = new ResonanceStaking(resToken, votes, rewards);
        pool = new ResonancePool(
            address(resToken),
            address(usdcToken),
            address(staking)
        );

        // filling up wallets and balances
        resToken.mint(user1, userAmounts);
        resToken.mint(user2, userAmounts);
        resToken.mint(address(staking), rewards);
        resToken.mint(address(pool), poolLiquidity);
        usdcToken.mint(user1, userAmounts);
        usdcToken.mint(user2, userAmounts);
        usdcToken.mint(address(pool), poolLiquidity);
    }

    function testInit() public view {
        assertEq(resToken.balanceOf(address(user1)), 2e6);
        assertEq(resToken.balanceOf(address(user2)), 2e6);
        assertEq(usdcToken.balanceOf(address(user1)), 2e6);
        assertEq(usdcToken.balanceOf(address(user2)), 2e6);
    }
}
