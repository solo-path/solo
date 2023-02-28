// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

interface ISolo {

    function firstDeposit(
        uint256 amountDeposit,
        uint256 amountQuote,
        int24 ticksRange,
        uint256 price
        // address to
    ) external;

    function deposit(
        uint256 amountDeposit,
        address to
    ) external returns (uint256 lpTokens);

    function withdraw(
        uint256 lpAmount, 
        address to
    ) external returns (uint256 amountDeposit, uint256 amountQuote);

    function swapExactInput(uint256 amount0, uint256 amount1) external 
        returns (uint256 output0, uint256 output1);

}