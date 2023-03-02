// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

interface ISolo {

    function pool() external view returns (address pool);
    function token0() external view returns (address token0);
    function token1() external view returns (address token1);
    function token0IsDeposit() external view returns (bool token0IsDeposit);

    function depositToken() external view returns (address token);
    function quoteToken() external view returns (address token);
    function currentTick() external view returns (int24 tick);
    function capitalAsQuoteTokens(uint256 price) external view returns (uint256 value);
    function protectedPosition() external view returns (uint256 amount0, uint256 amount1);
    function concentratedPosition() external view returns (uint256 amount0, uint256 amount1);
    function flexPosition() external view returns (uint256 amountDeposit, uint256 amountQuote);
    function tMin() external view returns (int24 tick);
    function tMax() external view returns (int24 tick);

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