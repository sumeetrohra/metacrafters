// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract fUSDC is ERC20, ERC20Permit {
    constructor() ERC20("fakeUSDC", "fUSDC") ERC20Permit("fakeUSDC") {}

    // Anyone who calls mint 10000 usdc with 18 decimals
    function mint() external {
        _mint(msg.sender, 10000000000000000000000);
    }
}
