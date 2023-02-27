// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract USDC is ERC20 {
    
    constructor() ERC20("USD Coin", "USDC"){
        _mint(msg.sender, 1 * 10 ** 6);
        _setupDecimals(6);
    }
}
