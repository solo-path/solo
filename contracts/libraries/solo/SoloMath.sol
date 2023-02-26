// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { E } from "@prb/math/src/ud60x18/Constants.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 @dev Percentages are high-precision decimals. 1e18 (1.0) is 100%.
 */

library SoloMath {

    using Strings for uint256;
    using SafeERC20 for IERC20;

    error Unacceptable(string reason);

    uint256 private constant ZERO = 0;
    uint256 private constant ONE = 1e18;
    uint256 private constant TWO = 2e18;
    uint256 private constant FOUR = 4e18;

    int256 private constant MIN_TICK = -887272 * 1e18;

    struct SoloState {
        UD60x18 x;
        UD60x18 y;
        SD59x18 tMax;
        SD59x18 tMin;
        UD60x18 sqrtPMin;
        UD60x18 sqrtPMax;
    }

    struct SoloContext {
        UD60x18 cX;
        UD60x18 cY;
        UD60x18 fX;
        UD60x18 fY;
        UD60x18 sqrtP;
        SD59x18 tC;
    }

    function zero() public pure returns (UD60x18 sdOne) {
        sdOne = ud(ZERO);
    }

    function one() public pure returns (UD60x18 sdOne) {
        sdOne = ud(ONE);
    }

    function oneSigned() public pure returns (SD59x18 sdOneSigned) {
        sdOneSigned = sd(int256(ONE));
    }

    function two() public pure returns (UD60x18 sdTwo) {
        sdTwo = ud(TWO);
    }

    function twoSigned() public pure returns (SD59x18 sdTwoSigned) {
        sdTwoSigned = sd(int256(TWO));
    }

    function minTick() public pure returns (SD59x18 sdMinTick) {
        sdMinTick = sd(MIN_TICK);
    }

    function maxTick() public pure returns (SD59x18 sdMaxTick) {
        sdMaxTick = sd(-MIN_TICK);
    }

    function four() public pure returns (UD60x18 sdFour) {
        sdFour = ud(FOUR);
    }

    function eq(UD60x18 a, UD60x18 b) public pure returns (bool equal) {
        equal = UD60x18.unwrap(a) == UD60x18.unwrap(b);
    }

    function eqS(SD59x18 a, SD59x18 b) public pure returns (bool equal) {
        equal = SD59x18.unwrap(a) == SD59x18.unwrap(b);
    }

    function lt(UD60x18 a, UD60x18 b) public pure returns (bool aLtB) {
        aLtB = UD60x18.unwrap(a) < UD60x18.unwrap(b);
    }

    function lte(UD60x18 a, UD60x18 b) public pure returns (bool aLteB) {
        aLteB = UD60x18.unwrap(a) <= UD60x18.unwrap(b);
    }

    function gt(UD60x18 a, UD60x18 b) public pure returns (bool aGtB) {
        aGtB = UD60x18.unwrap(a) > UD60x18.unwrap(b);
    }

    function gte(UD60x18 a, UD60x18 b) public pure returns (bool aGteB) {
        aGteB = UD60x18.unwrap(a) >= UD60x18.unwrap(b);
    }
    
    function min(UD60x18 a, UD60x18 b) public pure returns (UD60x18 minAB) {
        minAB = a.lt(b) ? a : b;
    }

    function max(UD60x18 a, UD60x18 b) public pure returns (UD60x18 maxAB) {
        maxAB = a.gt(b) ? a : b;
    }

    function minS(SD59x18 a, SD59x18 b) public pure returns (SD59x18 minAB) {
        minAB = a.lt(b) ? a : b;
    }

    function maxS(SD59x18 a, SD59x18 b) public pure returns (SD59x18 maxAB) {
        maxAB = a.gt(b) ? a : b;
    }

    function sq(UD60x18 a) public pure returns (UD60x18 square) {
        square = a.mul(a);
        require(a.eq(zero()) || !(square.eq(zero())), "sq resulted in 0");
    }

    function moreYthanX(
        SoloState storage self,
        SoloContext memory ctx
    ) public view returns (bool moreY) {
        moreY = self.y.gt(self.x.mul(sq(ctx.sqrtP)).div(one()));
    }

    function computeFlexPosition(
        SoloState storage self,
        SoloContext memory ctx,
        SD59x18 tPct
    ) public view returns (SD59x18 tMin, SD59x18 tMax) {
        tMin = computeTmin(self, ctx, tPct);
        tMax = computeTmax(self, ctx, tPct);
    }

    function computeTmin(
        SoloState storage self,
        SoloContext memory ctx,
        SD59x18 tPct
    ) public view returns (SD59x18 tMin) {
        // Formulas 4.1 and 4.2
        tMin = self.tMin;
        if (
            ctx.tC.sub(self.tMin).lt(
                self.tMax.sub(self.tMin).mul(tPct).div(twoSigned()))
        ) {
            tMin = maxS(minTick(), twoSigned().mul(ctx.tC).sub(self.tMax));
        }
    }

    function computeTmax(
        SoloState storage self,
        SoloContext memory ctx,
        SD59x18 tPct
    ) public view returns (SD59x18 tMax) {
        // Formulas 4.1 and 4.2
        tMax = self.tMax;
        if(
            self.tMax.sub(ctx.tC).lt(
                self.tMax.sub(self.tMin).mul(tPct).div(twoSigned()))
        ) {
            tMax = minS(maxTick(), twoSigned().mul(ctx.tC).sub(self.tMin));
        }
    }

    function computeAmountOfX(
        UD60x18 amountY,
        UD60x18 sqrtPMin,
        UD60x18 sqrtP,
        UD60x18 sqrtPMax
    ) public pure returns (UD60x18 amountX) {
        amountX = amountY.mul(
            sqrtPMax.sub(sqrtP)
        ).div(
            sqrtP.mul(sqrtPMax).mul(
                sqrtP.sub(sqrtPMin)
            )
        );
    }

    function computeAmountOfY(
        UD60x18 amountX,
        UD60x18 sqrtPMin,
        UD60x18 sqrtP,
        UD60x18 sqrtPMax
    ) public pure returns (UD60x18 amountY) {
        amountY = amountX.mul(
            sqrtP.mul(sqrtPMax).mul(
                sqrtP.sub(sqrtPMin)
            )
        ).div(
            sqrtPMax.sub(sqrtP)
        );
    }

    function computeFxFy(
        SoloState storage self, 
        SoloContext memory ctx,
        UD60x18 fPct
    ) public view returns (UD60x18 fX, UD60x18 fY) {
        if (moreYthanX(self, ctx)) {
            // Formula 4.4
            fX = self.x.mul(fPct).div(one());
            // Formula 4.6
            fY = computeAmountOfY(fX, self.sqrtPMin, ctx.sqrtP, self.sqrtPMax);
        } else {
            // Formula 4.7
            fY = self.y.mul(fPct).div(one());
            // Formula 4.5
            fX = computeAmountOfX(fY, self.sqrtPMin, ctx.sqrtP, self.sqrtPMax);
        }
    }

    // Section 4.3.2
    function computeCxCy(
        SoloState storage self,
        SoloContext memory ctx
    ) public view returns (UD60x18 cx, UD60x18 cy) {
        require(self.x.gte(ctx.fX) && self.y.gte(ctx.fY), "negative Cx/Cy");
        // Formula 4.8
        cx = self.x.sub(ctx.fX);
        // Formula 4.9
        cy = self.y.sub(ctx.fY);
    }
}