// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ResonanceStaking.sol";

/// @title Resonance Solidity CTF
/// @author Luis Arroyo
contract ResonancePool {
    IERC20 public token0; // RES Token
    IERC20 public token1; // USDC TOKEN
    address public staking;
    // LP balance
    mapping(address => uint) public balances0;
    mapping(address => uint) public balances1;

    uint256 public fee = 1; // 1% fee

    // Events
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount0, uint256 amount1);
    event WithdrawAll(address indexed user, uint256 amount0, uint256 amount1);
    event FeesSent(address indexed stakingProtocol, uint256 amount);
    event Swap(
        address indexed user,
        bool isToken0,
        uint256 amountIn,
        uint256 amountOut
    );

    // Ensure k = xy
    modifier invariantCheck() {
        uint256 k_before = token0.balanceOf(address(this)) *
            token1.balanceOf(address(this));
        _;
        uint256 k_after = token0.balanceOf(address(this)) *
            token1.balanceOf(address(this));
        require(k_before == k_after, "Invariant check failed");
    }

    /**
     * @dev Constructor to initialize the ResPool contract.
     * @param t0 Address of the RES token contract.
     * @param t1 Address of the USDC token contract.
     * @param _staking Address of the StakingProtocol contract.
     */
    constructor(address t0, address t1, address _staking) {
        token0 = IERC20(t0);
        token1 = IERC20(t1);
        staking = _staking;
    }

    /**
     * @dev Deposits the specified amount of USDC into the pool.
     * @param amount Amount of token0 to deposit.
     */
    function deposit(uint256 amount) external {
        token1.transferFrom(msg.sender, address(this), amount);
        balances1[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @dev Withdraws the specified amounts of token0 (RES) and token1 (USDC) from the pool.
     * @param amount0 Amount of token0 to withdraw.
     * @param amount1 Amount of token1 to withdraw.
     */
    function withdraw(uint256 amount0, uint256 amount1) external {
        balances0[msg.sender] -= amount0;
        balances1[msg.sender] -= amount1;
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);

        emit Withdraw(msg.sender, amount0, amount1);
    }

    /**
     * @dev Withdraws all deposited token0 (RES) and token1 (USDC) from the pool.
     */
    function withdrawAll() external {
        uint256 amount0 = balances0[msg.sender];
        uint256 amount1 = balances1[msg.sender];
        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
        balances0[msg.sender] = 0;
        balances1[msg.sender] = 0;

        emit WithdrawAll(msg.sender, amount0, amount1);
    }

    /**
     * @dev Sends the accumulated fees to the StakingProtocol contract to update the rewards pool.
     */
    function sendFees() external {
        uint256 amount = token0.balanceOf(address(this));
        ResonanceStaking(staking).updateRewardsPool(amount, address(this));

        emit FeesSent(staking, amount);
    }

    /**
     * @dev Swaps the input token for the output token.
     * @param isToken0 Boolean indicating if the input token is token0 (RES).
     * @param amountOut Desired amount of output tokens.
     */
    function swapOutToIn(
        bool isToken0,
        uint256 amountOut
    ) external invariantCheck {
        IERC20 tokenIn = isToken0 ? token0 : token1;
        IERC20 tokenOut = isToken0 ? token1 : token0;
        uint256 balanceIn = tokenIn.balanceOf(address(this));
        uint256 balanceOut = tokenOut.balanceOf(address(this));

        amountOut = (amountOut * (100 - fee)) / 100; // 1% fee send as staking reward

        //calculate amountIn using balancer formula without weights for simplicity
        // ai = bi * (bo / (bo - ao) - 1)
        uint256 division = balanceOut / (balanceOut - amountOut);
        uint256 factor = division * 1e6 - 1e6; // 1e6 is the precision
        uint256 amountIn = (balanceIn * factor) / 1e6;

        tokenOut.transfer(msg.sender, amountOut);
        tokenIn.transferFrom(msg.sender, address(this), amountIn);

        emit Swap(msg.sender, isToken0, amountIn, amountOut);
    }
}
