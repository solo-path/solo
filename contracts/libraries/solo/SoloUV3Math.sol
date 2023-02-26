// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { SoloTickMath } from "./SoloTickMath.sol";
import { SoloLiquidityAmounts } from "./SoloLiquidityAmounts.sol"; 
import { SoloOracleLibrary } from "./SoloOracleLibrary.sol";

library SoloUV3Math {

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /*******************
     * Tick Math
     *******************/
    
    function getSqrtRatioAtTick(
        int24 currentTick
    ) public pure returns(uint160 sqrtPriceX96) {
        sqrtPriceX96 = SoloTickMath.getSqrtRatioAtTick(currentTick);
    }

    /*******************
     * LiquidityAmounts
     *******************/

    function getAmountsForLiquidity(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint128 liquidity
    ) public pure returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = SoloLiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            liquidity);
    }

    function getLiquidityForAmounts(
        uint160 sqrtRatioX96,
        uint160 sqrtRatioAX96,
        uint160 sqrtRatioBX96,
        uint256 amount0,
        uint256 amount1
    ) public pure returns (uint128 liquidity) {
        liquidity = SoloLiquidityAmounts.getLiquidityForAmounts(
            sqrtRatioX96,
            sqrtRatioAX96,
            sqrtRatioBX96,
            amount0,
            amount1);
    }

    /*******************
     * OracleLibrary
     *******************/

    function consult(
        address _pool, 
        uint32 _twapPeriod
    ) public view returns(int24 timeWeightedAverageTick) {
        (timeWeightedAverageTick, ) = SoloOracleLibrary.consult(_pool, _twapPeriod);
    }

    function getQuoteAtTick(
        int24 tick,
        uint128 baseAmount,
        address baseToken,
        address quoteToken
    ) public pure returns (uint256 quoteAmount) {
        quoteAmount = SoloOracleLibrary.getQuoteAtTick(tick, baseAmount, baseToken, quoteToken);
    }

    /*******************
     * SafeUnit128
     *******************/

    /// @notice Cast a uint256 to a uint128, revert on overflow
    /// @param y The uint256 to be downcasted
    /// @return z The downcasted integer, now type uint128
    function toUint128(uint256 y) public  pure returns (uint128 z) {
        require((z = uint128(y)) == y, "SafeUint128: overflow");
    }
}

