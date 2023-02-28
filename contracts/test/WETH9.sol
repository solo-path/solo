// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract WETH9 is ERC20 {
    
    constructor() ERC20("Wrapped Ether", "WETH"){
        _mint(msg.sender, 1 * 10 ** 18);
        _setupDecimals(18);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}