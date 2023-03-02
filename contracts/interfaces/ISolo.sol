// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

interface ISolo {

    // error Unacceptable(string reason);

    /*
    event Deployed(
        address uv3PoolFactory,
        address pool,
        address tokenA,
        address tokenB,
        address token0,
        address token1,
        bool xIsDeposit,
        uint24 fee);

    event Init(
        UD60x18 bMin,
        SD59x18 tPct,
        UD60x18 s,
        UD60x18 dPct,
        UD60x18 fPct,
        UD60x18 rPct
    );
    */

    function depositToken() external view returns (address token);
    function quoteToken() external view returns (address token);
    function currentTick() external view returns (int24 tick);

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