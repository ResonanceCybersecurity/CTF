// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ResonanceToken is ERC20 {
    constructor() ERC20("Resonance Token", "RES") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
