// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.14;

//import '../libraries/solo/SoloMath.sol';
import { SoloMath } from "../libraries/solo/SoloMath.sol";
import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";

/**
 @notice Deploys a contract wrapper that exposes the library functions for direct interaction in tests.
 */

contract SoloMathTest {

    SoloMath.SoloState state;
    using SoloMath for SoloMath.SoloState;

    function zero() external pure returns (UD60x18 sdOne) {
        return SoloMath.zero();
    }

    function one() external pure returns (UD60x18 sdOne) {
        return SoloMath.one();
    }

    function oneSigned() external pure returns (SD59x18 sdOneSigned) {
        return SoloMath.oneSigned();
    }

    function two() external pure returns (UD60x18 sdTwo) {
        return SoloMath.two();
    }

    function twoSigned() external pure returns (SD59x18 sdTwoSigned) {
        return SoloMath.twoSigned();
    }

    function minTick() external pure returns (SD59x18 sdMinTick) {
        return SoloMath.minTick();
    }

    function maxTick() external pure returns (SD59x18 sdMaxTick) {
        return SoloMath.maxTick();
    }

    function four() external pure returns (UD60x18 sdFour) {
        return SoloMath.four();
    }

    function eq(UD60x18 a, UD60x18 b) external pure returns (bool) {
        return SoloMath.eq(a, b);
    }

    function lt(UD60x18 a, UD60x18 b) external pure returns (bool) {
        return SoloMath.lt(a, b);
    }

    function lte(UD60x18 a, UD60x18 b) external pure returns (bool) {
        return SoloMath.lte(a, b);
    }

    function gt(UD60x18 a, UD60x18 b) external pure returns (bool) {
        return SoloMath.gt(a, b);
    }

    function gte(UD60x18 a, UD60x18 b) external pure returns (bool) {
        return SoloMath.gte(a, b);
    }

    function min(UD60x18 a, UD60x18 b) external pure returns (UD60x18) {
        return SoloMath.min(a, b);
    }

    function max(UD60x18 a, UD60x18 b) external pure returns (UD60x18) {
        return SoloMath.max(a, b);
    }

    function minS(SD59x18 a, SD59x18 b) external pure returns (SD59x18) {
        return SoloMath.minS(a, b);
    }

    function maxS(SD59x18 a, SD59x18 b) external pure returns (SD59x18) {
        return SoloMath.maxS(a, b);
    }

    function sq(UD60x18 a) external pure returns (UD60x18) {
        return SoloMath.sq(a);
    }

    function computeFlexPosition(
        SD59x18 tC,
        SD59x18 tPct
    ) external view returns (SD59x18, SD59x18) {
        SoloMath.SoloContext memory ctx;
        ctx.tC = tC;
        return state.computeFlexPosition(ctx, tPct);
    }

    function setTminTmax(
        SD59x18 tMin,
        SD59x18 tMax
    ) external {
        state.tMin = tMin;
        state.tMax = tMax;
    }

    function computeTmin(
        SD59x18 tC,
        SD59x18 tPct
    ) external view returns (SD59x18) {
        SoloMath.SoloContext memory ctx;
        ctx.tC = tC;
        return state.computeTmin(ctx, tPct);
    }

    function computeTmax(
        SD59x18 tC,
        SD59x18 tPct
    ) external view returns (SD59x18) {
        SoloMath.SoloContext memory ctx;
        ctx.tC = tC;
        return state.computeTmax(ctx, tPct);
    }

}
