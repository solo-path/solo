// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { UD60x18, ud } from "@prb/math/src/UD60x18.sol";
import { SD59x18, sd } from "@prb/math/src/SD59x18.sol";
import { E } from "@prb/math/src/ud60x18/Constants.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SoloUV3Math, SoloTickMath, SoloOracleLibrary } from "./SoloUV3Math.sol";
import { IUniswapV3Pool } from "../../interfaces/IUniswapV3Pool.sol";

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

    // TODO there must be a way to reduce the number of structure and parameters

    struct SoloState {
        UD60x18 x;
        UD60x18 y;
        SD59x18 tMax;
        SD59x18 tMin;
        UD60x18 pf;
        UD60x18 sqrtPMin;
        UD60x18 sqrtPMax;
        uint256 protected0;
        uint256 protected1;
        uint256 blockNumber;
    }

    struct SoloContext {
        UD60x18 cX;
        UD60x18 cY;
        UD60x18 fX;
        UD60x18 fY;
        UD60x18 sqrtP;
        SD59x18 tC;
    }

    struct ScratchPad {
        UD60x18 ax;
        UD60x18 ay;
        UD60x18 xMax;
        UD60x18 yMax;
        UD60x18 deltaFx;
        UD60x18 deltaFy;
        UD60x18 pa;
        UD60x18 pb;
        UD60x18 cPct;
        UD60x18 b;
    }

    struct TradeState {
        UD60x18 fax;
        UD60x18 fay;
        UD60x18 cax;
        UD60x18 cay;
        UD60x18 acx;
        UD60x18 acy;
        UD60x18 cox;
        UD60x18 coy;
        UD60x18 ox;
        UD60x18 oy;
        int256 fox;
        int256 foy;
        uint256 concentratedSwapPrice;
        bool xForY;
        bool resetsConcentratedPosition;
    }

    // for debug purposes only
    struct TradeStateDebug {
        UD60x18 px;
        UD60x18 py;
        int256 ix;
        int256 iy;
        int256 cTick;
        uint256 ux;
        uint256 uy;
        bool xForY;
        bool b2;
    }

    struct TradeReq {
        UD60x18 rax;
        UD60x18 ray;
        UD60x18 fee;
        UD60x18 bMin;
        UD60x18 s_;
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
        // TODO doesn't work - getting RangeError: Maximum call stack size exceeded
        require(a.eq(zero()) || !(square.eq(zero())), "sq resulted in 0");
    }

    // util function to determine drection of the trade
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

    // util function (implements the main liquidity formula) - part 1
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

    // util function (implements the main liquidity formula) - part 2
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

    function computeCxCy(
        SoloState storage self,
        SoloContext memory ctx
    ) public view returns (UD60x18 cx, UD60x18 cy) {
        // TODO this check does not work. Need to debug why
        //require(self.x.gte(ctx.fX) && self.y.gte(ctx.fY), "negative Cx/Cy");
        // Formula 4.8
        cx = self.x.sub(ctx.fX);
        // Formula 4.9
        cy = self.y.sub(ctx.fY);
    }

    function preTradeAssessment(
        SoloState storage self, 
        SoloContext memory ctx,
        UD60x18 fPct,
        UD60x18 rPct
    ) public view returns (bool rebalance) {

        if (moreYthanX(self, ctx)) {
            // Formula 4.10
            // TODO why do we use lt(a,b) function here instead of simple lt?
            rebalance = lt(
                ctx.fX.mul(one().add(rPct)), 
                self.x.mul(fPct)
            );
        } else {
            // Formula 4.11
            rebalance = lt(
                ctx.fY.mul(one().add(rPct)), 
                self.y.mul(fPct)
            );
        }
    }

    // Steps for the actual swap go here

    // determines direction of the trade
    function step0(
        TradeState memory ts,
        TradeReq memory t
    ) public pure returns (
        TradeState memory)
    {
        ts.xForY = t.rax.gt(ud(0));
        return ts;
    }

    // Calculate the Ax or Ay, the specific quantity of either X or Y tokens used in the swap, 
    // by subtracting the fee.
    function step1(
        TradeState memory ts,
        ScratchPad memory s,
        TradeReq memory t
    ) public pure returns (
        TradeState memory,
        ScratchPad memory)
    {
        if(t.rax.gt(ud(0)) && t.ray.gt(ud(0))) 
            revert Unacceptable ({ reason: "rax and ray cannot both be > 0" });
        if(t.rax.eq(ud(0)) && t.ray.eq(ud(0))) 
            revert Unacceptable ({ reason: "rax and ray cannot both be 0" });
        ts.xForY = t.rax.gt(ud(0));

        if (ts.xForY) {
            // Formula 4.12
            s.ax = t.rax.mul(one().sub(t.fee));
        } else {
            // Formula 4.13
            s.ay = t.ray.mul(one().sub(t.fee));
        }

        return (ts, s);
    }


    // Step 3
    // Calculate the maximum price movement that a trade can cause without losing eligibility 
    // to use funds from the Concentrated position.
    // Have to split into 3 parts - otherwise stack is too deep

    function step3a(
        SoloState storage self, 
        TradeState memory ts,
        ScratchPad memory s,
        TradeReq memory t
    ) public view returns (
        TradeState memory,
        ScratchPad memory)
    {
        if (ts.xForY) {
            // Formula 4.14
            s.pa = self.pf.mul(one().sub(t.fee));
        } else {
            // Formula 4.15
            s.pb = self.pf.mul(one().add(t.fee));
        }
    
        return (ts, s);
    }

    function step3b(
        SoloState storage self, 
        SoloContext memory ctx,
        TradeState memory ts,
        ScratchPad memory s
    ) public view returns (
        TradeState memory,
        ScratchPad memory)
    {
        UD60x18 p = sq(ctx.sqrtP);
        if (ts.xForY) {
            if (s.pa.gte(p)) {
                // Formula 4.16
                s.yMax = zero();
            } else {
                // Formula 4.17
                s.yMax = computeAmountOfY(ctx.fX, s.pa.sqrt(), ctx.sqrtP, self.sqrtPMax);
            }
        } else {
            if (s.pb.lte(p)) {
                // Formula 4.18
                s.xMax = zero();
            } else {
                // Formula 4.19
                s.xMax = computeAmountOfX(ctx.fY, self.sqrtPMin, ctx.sqrtP, s.pb.sqrt());
            }
        }
    
        return (ts, s);
    }

    function step3c(
        TradeState memory ts,
        ScratchPad memory s
    ) public pure returns (
        TradeState memory,
        ScratchPad memory)
    {
        ts.resetsConcentratedPosition = false;
        
        if(ts.xForY) {
            // Formula 4.20
            if (s.yMax.div(s.pa).lt(s.ax)) {
                ts.fax = s.ax;
                ts.fay = ud(0);
                ts.cax = ud(0);
                ts.cay = ud(0);
                ts.resetsConcentratedPosition = true;
            }
        } else {
            // Formula 4.21
            if (s.xMax.mul(s.pb).lt(s.ay)) {
                ts.fax = ud(0);
                ts.fay = s.ay;
                ts.cax = ud(0);
                ts.cay = ud(0);
                ts.resetsConcentratedPosition = true;
            }
        }

        return (ts, s);
    }

    function step4(
        SoloState storage self,
        TradeState memory ts,
        ScratchPad memory s,
        TradeReq memory t
    ) public view returns (
        TradeState memory,
        ScratchPad memory)
    {
        // Formula 4.22
        s.b = ud((block.number - self.blockNumber) * ONE);

        if (t.bMin.gte(s.b)) {
            s.cPct = ud(0);
        } else {
            s.cPct = one().sub(one().div(E.pow(s.b.sub(t.bMin).div(t.s_))));
        }

        return (ts, s);
    }

    function step5( 
        SoloContext memory ctx,
        TradeState memory ts,
        ScratchPad memory s
    ) public pure returns (
        TradeState memory,
        ScratchPad memory)
    {
        if (ts.xForY) {
            // Formula 4.24
            ts.acy = ctx.cY.mul(s.cPct);
            // Formula 4.25
            s.deltaFy = s.ax.mul(sq(ctx.sqrtP));
            // Formula 4.26 - exact amount X in for flex pos trade
            ts.fax = s.ax.mul(s.deltaFy.div(s.deltaFy.add(ts.acy)));
            // Formula 4.27 - exact amount X in for concentrated pos trade
            ts.cax = s.ax.sub(ts.fax);
        } else {
            // Formula 4.23
            ts.acx = ctx.cX.mul(s.cPct);
            // Formula 4.28 (corrolary)
            s.deltaFx = s.ay.div(sq(ctx.sqrtP));
            // Formula 4.29
            ts.fay = s.ay.mul(s.deltaFx).div(s.deltaFx.add(ts.acx));
            // Formula 4.30
            ts.cay = s.ay.sub(ts.fay);
        }

        return (ts, s);
    }

    // reset the concentrated position - it'll take time to grow back up
    function resetConcentratedPosition(SoloMath.SoloState storage self) public {
        self.blockNumber = block.number;
    }

    // track the first price in the block
    function updatePf(SoloMath.SoloState storage self, UD60x18 p) public {
        uint256 blockNumber = block.number;
        if (self.blockNumber < blockNumber) {
            self.blockNumber = blockNumber;
            self.pf = p;
        }
    }

    function getSqrtPricesForMinMaxTicks(
        address depositToken,
        address quoteToken,
        SD59x18 tickMin_,
        SD59x18 tickMax_
    ) public pure returns (UD60x18 sqMin, UD60x18 sqMax) {
        sqMin = getPrbSqrtRatioAtTickSimple(depositToken, quoteToken, tickMin_);
        sqMax = getPrbSqrtRatioAtTickSimple(depositToken, quoteToken, tickMax_);
    }

    // moved here to reduce the contract size
    // TODO move it back to Solo.sol when possible
    function firstDeposit(
        SoloState storage self, 
        address pool,
        address depositToken,
        address quoteToken,
        uint256 amountDeposit,
        uint256 amountQuote,
        int24 ticksRange,
        uint256 price
    ) public {
        // commenting the check for now because of stack too deep
        /*uint256 balanceDepositToken = uint128(IERC20(depositToken).balanceOf(pool));
        uint256 balanceQuoteToken = uint128(IERC20(quoteToken).balanceOf(pool));
        require(balanceDepositToken == 0 && balanceQuoteToken == 0, "not empty");*/

        // initialize the underlying pool 
        uint160 sqrtPrice = _priceToSqrtX96(price, 18);
        IUniswapV3Pool(pool).initialize(sqrtPrice);

        int24 cTick_ = currentTick(pool);

        self.tMin = sd(cTick_ - ticksRange);
        self.tMax = sd(cTick_ + ticksRange);

        // this check is needed, but commented out for for to reduce contract size            
        require(self.tMin.gte(minTick()) && self.tMax.lte(maxTick()), "large range");

        (self.sqrtPMin, self.sqrtPMax) = 
            getSqrtPricesForMinMaxTicks(depositToken, quoteToken, self.tMin, self.tMax);

        // get users funds
        IERC20(depositToken).safeTransferFrom(msg.sender, address(this), amountDeposit);
        IERC20(quoteToken).safeTransferFrom(msg.sender, address(this), amountQuote);

        self.x = ud(amountDeposit);
        self.y = ud(amountQuote);

        // from here the rest of the logic resides in Solo.sol 
    }

    /**
     @notice returns price at a specfic tick
     @param depositToken_ depositToken
     @param quoteToken_ quoteToken
     @param tick_ tick
     @return price price
     */
    function tickToPrice(
        address depositToken_,
        address quoteToken_,
        int24 tick_
    ) public pure returns (uint256 price) {
        return
            SoloUV3Math.getQuoteAtTick(
                tick_, 
                uint128(1e18),
                depositToken_,
                quoteToken_
            );
    }

    function getSqrtRatioAtTick(int24 tickMin) public pure returns (uint160 sqrtRatio) {
        sqrtRatio = SoloTickMath.getSqrtRatioAtTick(tickMin);
    }

    function getSqrtRatioAtTickSimple(
        address depositToken_,
        address quoteToken_,
        int24 tick_
    ) public pure returns (uint160 sqrtRatio) {
        uint256 price = tickToPrice(depositToken_, quoteToken_, tick_);

        sqrtRatio = uint160(sqrtSimple(price * 1e18));
    }

    function getPrbSqrtRatioAtTickSimple(
        address depositToken_,
        address quoteToken_,
        SD59x18 tick
    ) public pure returns (UD60x18 sqrtRatio) {
        int24 tick_ = int24(SD59x18.unwrap(tick));
        sqrtRatio = ud(getSqrtRatioAtTickSimple(depositToken_, quoteToken_, tick_));
    }

    /// Converts a price into a sqrtX96
    /// @param _price The price to use
    /// @param _decimals price token decimals
    /// @return sqrtX96 The computed tick corresponding to that price
    function _priceToSqrtX96(uint256 _price, uint256 _decimals) public pure returns (uint160 sqrtX96) {
        if (_price < 10 ** _decimals) {
            return toSqrtX96_lower(_price, _decimals);
        } else {
            return toSqrtX96(_price, _decimals);
        }
    }

    function toSqrtX96(uint256 _x, uint256 _decimals) public pure returns (uint160) {
        return uint160(sqrtSimple(_x) * 2 ** 96 / sqrtSimple(10 ** _decimals));
    }

    function toSqrtX96_lower(uint256 _x, uint256 _decimals) public pure returns (uint160) {
        return uint160(sqrtSimple((_x << (96 * 2)) / (10 ** _decimals)));
    }

    function sqrtSimple(uint256 y) public pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    /**
     @notice Returns current price tick
     @param tick Uniswap pool's current price tick
     */
    function currentTick(address pool) public view returns (int24 tick) {
        (, int24 tick_, , , , , bool unlocked_) = IUniswapV3Pool(pool).slot0();
        require(unlocked_, "IV.currentTick: the pool is locked");
        tick = tick_;
    }

    /**
     @notice uint128Safe function.
     @param x input value.
     @return uint128 x, provided overflow has not occured.
     */
    function _uint128Safe(uint256 x) public pure returns (uint128) {
        require(x <= type(uint128).max, "IV.128_OF");
        return uint128(x);
    }

    /**
     @notice uint160Safe function.
     @param x input value.
     @return uint160 x, provided overflow has not occured.
     */
    function _uint160Safe(uint256 x) public pure returns (uint160) {
        require(x <= type(uint128).max, "IV.160_OF");
        return uint160(x);
    }

/**
     @notice Mint liquidity in Uniswap V3 pool.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param liquidity Amount of liquidity to mint
     @param amount0 Used amount of token0
     @param amount1 Used amount of token1
     */
    function _mintLiquidity(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public returns (uint256 amount0, uint256 amount1) {
        if (liquidity > 0) {
            (amount0, amount1) = IUniswapV3Pool(pool).mint(
                address(this),
                tickLower,
                tickUpper,
                liquidity,
                abi.encode(address(this))
            );
        }
    }

    /**
     @notice Burn liquidity in Uniswap V3 pool.
     @param liquidity amount of liquidity to burn
     @param tickLower The lower tick of the flex liquidity position
     @param tickUpper The upper tick of the flex liquidity position
     @param to The account to receive token0 and token1 amounts
     @param collectAll Flag that indicates whether all token0 and token1 tokens should be collected or only the ones released during this burn
     @param amount0 released amount of token0
     @param amount1 released amount of token1
     */
    function _burnLiquidity(
        address pool,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        address to,
        bool collectAll
    ) public returns (uint256 amount0, uint256 amount1) {
        if (liquidity > 0) {
            // Burn liquidity
            (uint256 owed0, uint256 owed1) = IUniswapV3Pool(pool).burn(
                tickLower,
                tickUpper,
                liquidity
            );

            // Collect amount owed
            uint128 collect0 = collectAll
                ? type(uint128).max
                : _uint128Safe(owed0);
            uint128 collect1 = collectAll
                ? type(uint128).max
                : _uint128Safe(owed1);
            if (collect0 > 0 || collect1 > 0) {
                (amount0, amount1) = IUniswapV3Pool(pool).collect(
                    to,
                    tickLower,
                    tickUpper,
                    collect0,
                    collect1
                );
            }
        }
    }

    function uniswapV3MintCallback(
        address pool,
        address token0,
        address token1,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "cb1");
        address payer = abi.decode(data, (address));

        if (payer == address(this)) {
            if (amount0 > 0) IERC20(token0).safeTransfer(msg.sender, amount0);
            if (amount1 > 0) IERC20(token1).safeTransfer(msg.sender, amount1);
        } else {
            if (amount0 > 0)
                IERC20(token0).safeTransferFrom(payer, msg.sender, amount0);
            if (amount1 > 0)
                IERC20(token1).safeTransferFrom(payer, msg.sender, amount1);
        }
    }

    function uniswapV3SwapCallback(
        address pool,
        address token0,
        address token1,
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "cb2");
        address payer = abi.decode(data, (address));

        if (amount0Delta > 0) {
            if (payer == address(this)) {
                IERC20(token0).safeTransfer(msg.sender, uint256(amount0Delta));
            } else {
                IERC20(token0).safeTransferFrom(
                    payer,
                    msg.sender,
                    uint256(amount0Delta)
                );
            }
        } else if (amount1Delta > 0) {
            if (payer == address(this)) {
                IERC20(token1).safeTransfer(msg.sender, uint256(amount1Delta));
            } else {
                IERC20(token1).safeTransferFrom(
                    payer,
                    msg.sender,
                    uint256(amount1Delta)
                );
            }
        }
    }

    /**
     @notice Calculates amount of liquidity in a position for given token0 and token1 amounts
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param amount0 token0 amount
     @param amount1 token1 amount
     */
    function liquidityForAmounts(
        address pool,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0,
        uint256 amount1
    ) public view returns (uint128) {
        (uint160 sqrtRatioX96, , , , , , ) = IUniswapV3Pool(pool).slot0();
        return
            SoloUV3Math.getLiquidityForAmounts(
                sqrtRatioX96,
                getSqrtRatioAtTick(tickLower),
                getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /**
     @notice returns equivalent _tokenOut for _amountIn, _tokenIn using spot price
     @param tokenIn token the input amount is in
     @param tokenOut token for the output amount
     @param amountIn amount in _tokenIn
     @return amountOut equivalent anount in _tokenOut
     */
    function spot(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint160 amountOut) { 
        return
            (
                _uint160Safe(SoloUV3Math.getQuoteAtTick(
                    currentTick(pool),
                    SoloUV3Math.toUint128(amountIn),
                    tokenIn,
                    tokenOut
                ))
            );
    } 

    /**
     @notice returns equivalent _tokenOut for _amountIn, _tokenIn using TWAP price
     @param _twapPeriod the averaging time period
     @param _amountIn amount in _tokenIn
     @param amountOut equivalent anount in _tokenOut
     */
    function twap(
        address pool,
        address depositToken_,
        address quoteToken_,
        uint32 _twapPeriod,
        uint256 _amountIn
    ) public view returns (uint256 amountOut) {
        uint32 oldestSecondsAgo = SoloOracleLibrary.getOldestObservationSecondsAgo(pool);
        _twapPeriod = (_twapPeriod < oldestSecondsAgo) ? _twapPeriod : oldestSecondsAgo;
        int256 twapTick = SoloUV3Math.consult(pool, _twapPeriod);
        return
            SoloUV3Math.getQuoteAtTick(
                int24(twapTick), // can assume safe being result from consult()
                SoloUV3Math.toUint128(_amountIn),
                depositToken_,
                quoteToken_
            );
    }

    // e.g. Solo WETH-USDC-50
    function lpName(address token0, address token1, UD60x18 dPct) public view returns (string memory lpName_) {
        lpName_ = string.concat("Solo ", lpSymbol(
            token0,
            token1,
            dPct
        ));
    }
    // e.g. WETH-USDC-50
    function lpSymbol(address token0, address token1, UD60x18 dPct) public view returns (string memory lpSymbol_) {
        IERC20Metadata x = IERC20Metadata(token0);
        IERC20Metadata y = IERC20Metadata(token1);
        string memory xSymbol = x.symbol();
        string memory ySymbol = y.symbol();
        lpSymbol_ = string.concat(string.concat(string.concat(string.concat(xSymbol,"-"), ySymbol), ":"), dPctString(dPct)); 
    }

    function dPctString(UD60x18 dPct) public pure returns (string memory shortString) {
        shortString = Strings.toString(uint256(UD60x18.unwrap(dPct)) / 1e16);
    }

}