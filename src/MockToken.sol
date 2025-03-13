// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title Resonance Solidity CTF
/// @author Luis Arroyo & João Simões
contract MockToken is ERC20 {
    constructor() ERC20("USDC token mock", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
