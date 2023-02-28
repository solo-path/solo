// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract DAI is ERC20 {
    
    constructor() ERC20("Dai Stablecoin", "DAI"){
        _mint(msg.sender, 1 * 10 ** 18);
        _setupDecimals(18);
    }
}