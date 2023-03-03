// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { ISolo } from "../interfaces/ISolo.sol";
import { IUniswapV3Pool } from "../interfaces/IUniswapV3Pool.sol";
import { IUniswapV3Factory } from "../interfaces/IUniswapV3Factory.sol";
import { IUniswapV3MintCallback } from "../interfaces/callback/IUniswapV3MintCallback.sol";
import { IUniswapV3SwapCallback } from "../interfaces/callback/IUniswapV3SwapCallback.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SoloUV3Math, SoloTickMath, SoloOracleLibrary } from "../libraries/solo/SoloUV3Math.sol";
import { SoloMath, SD59x18, UD60x18, sd, ud } from "../libraries/solo/SoloMath.sol";

contract Solo is ISolo, 
    ERC20,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback, 
    Initializable, 
    ReentrancyGuard {

    using SoloMath for SoloMath.SoloState;
    using SoloMath for address;
    using SoloMath for uint256;
    using SoloMath for int256;
    using SoloMath for uint160;
    using SoloMath for SD59x18;
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    address private constant ADDRESS_NULL = address(0);
    uint256 private constant ONE = 1e18;
    uint256 private constant FIVE = 5e18;
    uint256 private constant HUNDRED = 100e18;
    uint32 private constant FIVE_MINUTES = 5 minutes;
    uint32 private constant FIFTEEN_MINUTES = 15 minutes;

    // pool used to hold the Flex position
    address public immutable override pool;
    // token0 in the pool
    address public immutable override token0;
    // token1 in the pool
    address public immutable override token1;
    // used to determine which pool token is deposit token
    bool public immutable override token0IsDeposit;

    // Minimum number of blocks since the last reset
    UD60x18 public bMin;
    // Trading Range threshold (percentage)
    // Used to determine how many ticks the price can move within Flex posistion 
    // before causing expansion of the flex position.
    SD59x18 public tPct;
    // Speed parameter for the concentration increase after a reset
    UD60x18 public s;
    // Pool’s Trading Fee
    UD60x18 public fee;
    // Percentage of deposit tokens to be allocated to the Protected position
    UD60x18 public dPct;
    // Maximum percent of x and y to be placed into the Flex liquidity position
    UD60x18 public fPct;
    // Rebalance threshold (percentage)
    // Used to determine the maximum size at which the Flex position could grow before triggering a rebalance.
    UD60x18 public rPct;

    // state of the pool with all positions
    SoloMath.SoloState private app;

    // Structures used for debugging only
    // SoloMath.SoloContext public ctx_;
    SoloMath.TradeStateDebug public ts_;

    constructor(
        address uv3PoolFactory_,
        address tokenA_,
        address tokenB_,
        bool tokenAIsDeposit_,
        uint256 fee_,
        string memory lpName,
        string memory lpSymbol
    )
    ERC20(
        lpName, 
        lpSymbol
    )
    {
        // call on Uniswap Factory to deploy a pool
        pool = IUniswapV3Factory(uv3PoolFactory_).createPool(
            tokenA_,
            tokenB_,
            // 0.01%
            100
        );

        // find out relationship between token0/token1, tokenA/tokenB and deposit/quote tokens 
        bool tokenAIsToken0 = tokenA_ < tokenB_;
        token0IsDeposit = (tokenAIsToken0 && tokenAIsDeposit_) || (!tokenAIsToken0 && !tokenAIsDeposit_);

        token0 = tokenAIsToken0 ? tokenA_ : tokenB_;
        token1 = tokenAIsToken0 ? tokenB_ : tokenA_;
        fee = ud(fee_);
    }

    function init(
        UD60x18 bMin_,
        SD59x18 tPct_,
        UD60x18 s_,
        UD60x18 dPct_,
        UD60x18 fPct_,
        UD60x18 rPct_
    ) external initializer {
        bMin = bMin_;
        tPct = tPct_;
        s = s_;
        dPct = dPct_;
        fPct = fPct_;
        rPct = rPct_;
    }

    /**
     @notice this must be called after the solo pool is created
        sets the price, initial range for the flex position and deploys initial funds into the pool 
     @param amountDeposit initial amount of deposit token
     @param amountDeposit initial amount of quote token
     @param ticksRange range of the flex position in ticks (position will be set as cTick-ticksRange/cTick+ticksRange)
     @param price price of deposit token in quote tokens
     */
    function firstDeposit(
        uint256 amountDeposit,
        uint256 amountQuote,
        int24 ticksRange,
        uint256 price
        // address to
    ) external override {
        // require that the pool has no money
        // nothing to protected position
        // Some quote tokens to flex position and some to concentrated.
        // Some deposit tokens to flex and some to concentrated.
        // Same formulation as regular deposit. (to calculate LPs)
        // Set the price in Uv3 pool.

        app.firstDeposit(
            pool,
            depositToken(),
            quoteToken(),
            amountDeposit,
            amountQuote,
            ticksRange,
            price
        );

        SoloMath.SoloContext memory ctx = getContext();

        // set proper fX and fY (so some amount if set aside for cX and cY)
        (ctx.fX, ctx.fY) = app.computeFxFy(ctx, fPct);

        // set the Flex position
        putFlexPosition(ctx);

        // debugging here
        // int24 tickLower = int24(SD59x18.unwrap(app.tMin));
        // int24 tickUpper = int24(SD59x18.unwrap(app.tMax));
        // putFlexPositionOldWay(tickLower, tickUpper, amountDeposit, amountQuote);
        // end of debugging

        UD60x18 valueOfDeposit = ud(amountQuote).add(ud(amountDeposit).mul(ud(price)));

        app.updatePf(ud(price));

        _mint(msg.sender, uint256(UD60x18.unwrap(valueOfDeposit)));
    }

    /**
     @param amountDeposit Amount of deposit token transfered from sender
     @param to Address to which liquidity tokens are minted
     @return lpTokens Quantity of liquidity tokens minted as a result of deposit
     */
    function deposit(
        uint256 amountDeposit,
        address to
    ) external override nonReentrant returns (uint256 lpTokens) {

        // TODO add check for totalSupply > 0. This should never be the case, because firstDeposit must come in first

        UD60x18 spotPrice = ud(pool.spot(depositToken(), quoteToken(), ONE));
        UD60x18 twapPrice = ud(pool.twap(depositToken(), quoteToken(), FIVE_MINUTES, ONE));
        UD60x18 offeredPrice = SoloMath.min(spotPrice, twapPrice);

        //UD60x18 percent5 = ud(FIVE).div(ud(HUNDRED));
        UD60x18 toProtected = dPct.mul(ud(amountDeposit));
        UD60x18 toMain = ud(amountDeposit).sub(toProtected);

        // TODO if the difference between the spot price and the 15 minute TWAP is more than 5%

        /*if(ud(pool.spot(depositToken(), quoteToken(), ONE)).div(
            ud(pool.twap(depositToken(), quoteToken(), FIFTEEN_MINUTES, ONE))).gt(percent5)) {
            revert ("v");
        }*/

        // or the price change in the block is more than twice the trading fee

        UD60x18 delta = (offeredPrice.gt(app.pf)) ? offeredPrice.sub(app.pf) : app.pf.sub(offeredPrice);
        if(delta.div(app.pf).gt(fee.mul(SoloMath.two()))) {
            revert ("m");
        }

        UD60x18 valueOfDeposit = offeredPrice.mul(ud(amountDeposit));
        UD60x18 valueIncreasePercent = 
            valueOfDeposit.div(
                ud(capitalAsQuoteTokens(UD60x18.unwrap(SoloMath.max(spotPrice, twapPrice))))
            );
 
        // change app.protected after getting the tvl calculated
        if (token0IsDeposit) {
            app.protected0 = app.protected0 + UD60x18.unwrap(toProtected);
            app.x = app.x.add(toMain);
        } else {
            app.protected1 = app.protected1 + UD60x18.unwrap(toProtected);
            app.y = app.y.add(toMain);
        }
 
        // move deposits after capitalAsQuoteTokens is calculated
        ERC20(depositToken()).safeTransferFrom(msg.sender, address(this), amountDeposit);

        UD60x18 lpAmount = ud(totalSupply()).mul(valueIncreasePercent);
        lpTokens = UD60x18.unwrap(lpAmount);
        _mint(to, lpTokens);

        // The allocation of tokens between the Flex position and the Concentrated position is reassessed after deposits 
        // and before trades.  
        if(bMin.lt(ud((block.number - app.blockNumber) * 1e18))) {
            SoloMath.SoloContext memory ctx = getContext();            
            (ctx.fX, ctx.fY) = app.computeFxFy(ctx, fPct);
            pullFlexPosition();
            putFlexPosition(ctx);
        }

        app.updatePf(spotPrice);
    }

    // proportionally reduce all positions (used during withdraw)
    function reducePositions(uint256 lpAmount) internal 
        returns (uint256 amountDeposit, uint256 amountQuote) 
    {
        uint256 lpSupply = totalSupply();

        (uint256 protected0, uint256 protected1) = protectedPosition();
        (uint256 concentrated0, uint256 concentrated1) = concentratedPosition();

        uint256 amt_p0 = lpAmount * protected0 / lpSupply;
        uint256 amt_p1 = lpAmount * protected1 / lpSupply;
        uint256 amt_c0 = lpAmount * concentrated0 / lpSupply;
        uint256 amt_c1 = lpAmount * concentrated1 / lpSupply;

        app.protected0 -= amt_p0;
        app.protected1 -= amt_p1;

        if (token0IsDeposit) {
            amountDeposit += amt_p0 + amt_c0;
            amountQuote += amt_p1 + amt_c1;
            app.x = app.x.sub(ud(amt_c0));
            app.y = app.y.sub(ud(amt_c1));
        } else {
            amountDeposit += amt_p1 + amt_c1;
            amountQuote += amt_p0 + amt_c0;
            app.x = app.x.sub(ud(amt_c1));
            app.y = app.y.sub(ud(amt_c0));
        }
    }

    /**
     @notice Liquidity Removal
        A user may redeem their pool tokens for both quote and deposit assets at the current mix in the pool
        without experiencing slippage.  Upon redemption, the number of protected tokens is adjusted in the same 
        proportion as the overall LP tokens.
     @param lpAmount Number of liquidity tokens to redeem as pool assets
     @param to Address to which redeemed pool assets are sent
     @return amountDeposit Amount of deposit tokens redeemed by the submitted liquidity tokens
     @return amountQuote Amount of quote tokens redeemed by the submitted liquidity tokens
     */
    function withdraw(uint256 lpAmount, address to) external override nonReentrant 
        returns (uint256 amountDeposit, uint256 amountQuote) {
        app.updatePf(ud(pool.spot(depositToken(), quoteToken(), ONE)));

        //transferFrom(msg.sender, address(this), lpAmount);

        // Withdraw ratio amount of protected and concentrated
        // must be done before flex position is burned
        (amountDeposit, amountQuote) = reducePositions(lpAmount);

        // Withdraw ratio amount of liquidity

        int24 tickLower = int24(SD59x18.unwrap(app.tMin));
        int24 tickUpper = int24(SD59x18.unwrap(app.tMax));

        (uint256 amount0, uint256 amount1) = SoloMath._burnLiquidity(
            pool,
            _liquidityForShares(tickLower, tickUpper, lpAmount),
            tickLower,
            tickUpper,
            address(this), 
            false);

        if (token0IsDeposit) {
            amountDeposit += amount0;
            amountQuote += amount1;
            app.x = app.x.sub(ud(amount0));
            app.y = app.y.sub(ud(amount1));
        } else {
            amountDeposit += amount1;
            amountQuote += amount0;
            app.x = app.x.sub(ud(amount1));
            app.y = app.y.sub(ud(amount0));
        }

        // burn after _burnLiquidity, because totalSupply is used in there
        _burn(msg.sender, lpAmount);

        // send sums to user
        ERC20(depositToken()).safeTransfer(to, amountDeposit);
        ERC20(quoteToken()).safeTransfer(to, amountQuote);
    }

    /**
     @notice swap one token for another
     @param amount0 amount of token0 to swap (if zero, means the other token is being swapped)
     @param amount1 amount of token1 to swap (if zero, means the other token is being swapped)
     @return output0 amount of aquired token0
     @return output1 amount of aquired token1
     @return concentrated0 amount of aquired token0 from the concentrated position
     @return concentrated1 amount of aquired token1 from the concentrated position
     */
    function swapExactInput(
        uint256 amount0, 
        uint256 amount1
    ) external override nonReentrant 
        returns (uint256 output0, uint256 output1, uint256 concentrated0, uint256 concentrated1) {

        if (amount0 * amount1 != 0) revert ( "a" );

        SoloMath.SoloContext memory ctx = getContext();
        SoloMath.TradeState memory ts;
        SoloMath.TradeReq memory t = SoloMath.TradeReq({
            rax: ud(amount0),
            ray: ud(amount1),
            fee: fee,
            bMin: bMin,
            s_: s 
        });

        // Determines direction of the trade
        ts = SoloMath.step0(
            ts,
            t
        );

        // Reset and/or rebalance the Flex position
        conditionalRebalance(ctx, ts);

        // Transfer funds in
        amount0 > 0 ? 
            ERC20(token0).safeTransferFrom(msg.sender, address(this), amount0) :
            ERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);
        
        // if(amount0 == 0 && amount1 == 0) revert("not possible?")

        /* The following steps are coordinated in tokensUsed() below.
        Step 1
        Calculate the Ax or Ay, the specific quantity of either X or Y tokens used in the swap, by subtracting the fee.
        Step 3
        Estimate the new price (P') that would be reached if the trade is executed solely against the Flex position in 
        order to determine eligibility for a partial expanded range swap.
        Step 4
        Determine the amount of tokens that could be sold from the Concentrated position.
        Step 5
        Determine amounts of tokens to be traded against the Flex position (FAx and FAy) and against the 
        Concentrated position (CAx and CAy).
        */
        ts = tokensUsed(
            ts,
            t,
            ctx
        );

        app.updatePf(ud(pool.spot(depositToken(), quoteToken(), ONE)));

        if (ts.resetsConcentratedPosition) {
            // ... all swap to flex position (amountX, amountY) execute reset, exit
            // note that the token purchased comes out as negative number
            (ts.fox, ts.foy) = IUniswapV3Pool(pool).swap(
                address(this),
                ts.xForY,
                (ts.xForY) ? int256(UD60x18.unwrap(ts.fax)) : int256(UD60x18.unwrap(ts.fay)),
                (ts.xForY) ? 
                      SoloUV3Math.MIN_SQRT_RATIO + 1
                    : SoloUV3Math.MAX_SQRT_RATIO - 1,
                abi.encode(address(this))
            );
            app.resetConcentratedPosition();

            if(ts.xForY) {
                ERC20(token1).transfer(msg.sender, uint256(-ts.foy));

                // update app.x and app.y after a trade
                // take full amount in, subtract tokens given out
                app.x = app.x.add(t.rax);
                app.y = app.y.sub(ud(uint256(-ts.foy)));

                return (uint256(ts.fox), uint256(-ts.foy), 0, 0);
            } else {
                ERC20(token0).transfer(msg.sender, uint256(-ts.fox));

                // update app.x and app.y after a trade
                // take full amount in, subtract tokens given out
                app.x = app.x.sub(ud(uint256(-ts.fox)));
                app.y = app.y.add(t.ray);

                return (uint256(-ts.fox), uint256(ts.foy), 0, 0);
            }
        }

        /*
        Execute swap control flow for the partial trade against the Flex position using FAx or FAy amount from Step 5.
        */
       
        // One of these will be positive and exact - amount tokens received.
        // note that the token purchased comes out as negative number
        (ts.fox, ts.foy) = IUniswapV3Pool(pool).swap(
            address(this),
            ts.xForY,
            (ts.xForY) ? int256(UD60x18.unwrap(ts.fax)) : int256(UD60x18.unwrap(ts.fay)),
            (ts.xForY)  
                ? SoloUV3Math.MIN_SQRT_RATIO + 1
                : SoloUV3Math.MAX_SQRT_RATIO - 1,
            abi.encode(address(this))
        );

        /*
        Step 6
        When the swap flow is completed the pool will acquire a new spot price (SP).
        The flow will also produce the exact amount of output tokens (FOx or FOy) from the partial trade.
        */

        ts.concentratedSwapPrice = ((pool.spot(depositToken(), quoteToken(), ONE)))._uint160Safe();

        // Step 7
        if (ts.xForY) {
            UD60x18 spotXForY = ud(ts.concentratedSwapPrice);
            // Formula 4.29
            ts.coy = ts.cax.mul(spotXForY);
            // Formula 4.30
            ts.oy = SoloMath.min(ts.coy, ts.acy).add(ud(uint256(-ts.foy)));

            // update app.x and app.y after a trade
            // take full amount in, subtract tokens given out
            app.x = app.x.add(t.rax);
            app.y = app.y.sub(ts.oy);

            // oy + foy to trader
            ERC20(token1).safeTransfer(msg.sender, UD60x18.unwrap(ts.oy)); // Y is token1
        } else {
            UD60x18 spotYForX = SoloMath.one().div(ud(ts.concentratedSwapPrice));
            // Formula 4.29
            ts.cox = ts.cay.div(spotYForX);
            // Formula 4.30
            ts.ox = SoloMath.min(ts.cox, ts.acx).add(ud(uint256(-ts.fox)));

            // update app.x and app.y after a trade
            // take full amount in, subtract tokens given out
            app.x = app.x.sub(ts.ox);
            app.y = app.y.add(t.ray);

            // ox + fox to trader
            ERC20(token0).safeTransfer(msg.sender, UD60x18.unwrap(ts.ox)); // X is token0
        }

        return (UD60x18.unwrap(ts.ox), UD60x18.unwrap(ts.oy), 
                UD60x18.unwrap(SoloMath.min(ts.cox, ts.acx)), 
                UD60x18.unwrap(SoloMath.min(ts.coy, ts.acy)));
    }

    // math for trade simulation goes here
    function tokensUsed(
        SoloMath.TradeState memory ts,
        SoloMath.TradeReq memory t,
        SoloMath.SoloContext memory ctx
    ) internal view returns (SoloMath.TradeState memory) {
        SoloMath.ScratchPad memory s_;

        (ts, s_) = SoloMath.step1(
            ts,
            s_,
            t
        );

        (ts, s_) = SoloMath.step3a(
            app,
            ts,
            s_,
            t
        );

        (ts, s_) = SoloMath.step3b(
            app,
            ctx,
            ts,
            s_
        );

        (ts, s_) = SoloMath.step3c( 
            ts,
            s_
        );

        if (!ts.resetsConcentratedPosition) {            
            // if we need to reset the concentrated position, then the rest of the steps must be skipped
            (ts, s_) = SoloMath.step4(
                app,
                ts,
                s_,
                t   
            );

            (ts, s_) = SoloMath.step5(
                ctx,
                ts,
                s_
            );
        }

        return (ts);
    }

    function depositToken() public override view returns (address token) {
        token = (token0IsDeposit) ? token0 : token1;
    }

    function quoteToken() public override view returns (address token) {
        token = (token0IsDeposit) ? token1 : token0;
    }

    function currentTick() public override view returns (int24 tick) {
        tick = pool.currentTick();
    }

    // rebalances and resets the flex position if needed
    function conditionalRebalance(
        SoloMath.SoloContext memory ctx,
        SoloMath.TradeState memory ts
    ) internal returns (SoloMath.SoloContext memory) {

        /*
            Substeps:
            a) determine direction of the proposed trade (ts.xForY)
            b) call computeFlexPosition. If resulting Tmin/Tmax differ from current Tmin/Tmax values and the trade
                is in the direction of pushing the boundary further out, the rebalance is required before the trade
                is executed. Go to substep e) 
            c) call computeFxFy to compute possible Fx and Fy
            d) call preTradeAssessment with Fx and Fy from substep b) to see if rebalance is needed. 
                If yes, go to substep e)
                Otherwise, skip to substep f)
            e) reset Flex position in UniV3 using Tmin/Tmax (from c)) and Fx/Fy (from b)) 
            f) obtain Fx and Fy from the current Flex position
            g) call computeCxCy to compute Cx and Cy
        */

        SD59x18 newTMin;
        SD59x18 newTMax;

        // a) ts.xForY is already set in ts

        // b)

        (newTMin, newTMax) = app.computeFlexPosition(ctx, tPct);
        
        if(!newTMin.eq(app.tMin) && ts.xForY) {
            // e)
            (uint256 amount0, uint256 amount1) = pullFlexPosition();
            app.tMin = newTMin;
            ctx.fX = ud(amount0);
            ctx.fY = ud(amount1);
            putFlexPosition(ctx);
        } else if(!newTMax.eq(app.tMax) && !ts.xForY) {
            // e)
            (uint256 amount0, uint256 amount1) = pullFlexPosition();
            app.tMax = newTMax;
            ctx.fX = ud(amount0);
            ctx.fY = ud(amount1);
            putFlexPosition(ctx);
        } else {
            if(bMin.lt(ud((block.number - app.blockNumber) * 1e18))) {
                // c
                (ctx.fX, ctx.fY) = app.computeFxFy(ctx, fPct);
                // d) call preTradeAssessment to see if Flex and Concentrated positions should be rebalanced
                // A rebalance is executed prior to a trade if either (4.10) or (4.11) is TRUE.
                if(app.preTradeAssessment(ctx, fPct, rPct)) {
                    pullFlexPosition();
                    // the position will get placed back within the same boundaries but with different fX and fY
                    putFlexPosition(ctx);
                }
            }
        }

        // f) determine actual fX and fY amounts in Flex position
        (uint256 amountDeposit, uint256 amountQuote) = flexPosition();
        ctx.fX = ud(amountDeposit);
        ctx.fY = ud(amountQuote);
        
        // g) determine cX and cY amounts in Concentrated position

        (ctx.cX, ctx.cY) = app.computeCxCy(ctx);
        return ctx;
    }

    function pullFlexPosition() internal returns (uint256 amount0, uint256 amount1) {
        (uint128 liquidity, , ) = _flexPosition(
            int24(SD59x18.unwrap(app.tMin)),
            int24(SD59x18.unwrap(app.tMax))
        );
        (amount0, amount1) = SoloMath._burnLiquidity(
            pool,
            liquidity,
            int24(SD59x18.unwrap(app.tMin)),
            int24(SD59x18.unwrap(app.tMax)),
            address(this),
            true
        );
    }

    function putFlexPosition(
        SoloMath.SoloContext memory ctx
    ) internal returns (uint256 amount0, uint256 amount1){
        int24 tickLower = int24(SD59x18.unwrap(app.tMin));
        int24 tickUpper = int24(SD59x18.unwrap(app.tMax));

        uint256 liquidity = pool.liquidityForAmounts(
            tickLower,
            tickUpper,
            UD60x18.unwrap(ctx.fX),
            UD60x18.unwrap(ctx.fY)
        );

        (amount0, amount1) = SoloMath._mintLiquidity(
            pool,
            tickLower, 
            tickUpper, 
            uint128(liquidity));
    }

    function getContext() public view returns (SoloMath.SoloContext memory context) {
        // TODO probably possible to drop this structure completely, or merge other things into it
        
        UD60x18 uninitialized;

        int24 cTick_ = currentTick();
        uint256 sqPrice_ = SoloMath.getSqrtRatioAtTickSimple(depositToken(), quoteToken(), cTick_);


        context = SoloMath.SoloContext({
            cX: uninitialized,
            cY: uninitialized,
            fX: uninitialized,
            fY: uninitialized,
            sqrtP: ud(sqPrice_),
            tC: sd(cTick_)
        });
    }

    /**
     @notice Calculate total value of the pool in quote tokens.
     @return value total value of the pool
     */
    function capitalAsQuoteTokens(uint256 price) public override view returns (uint256 value) {
        uint256 totalDeposit;
        uint256 totalQuote;
        (uint256 amountDeposit, uint256 amountQuote) = flexPosition();
        (uint256 protected0, uint256 protected1) = protectedPosition();
        (uint256 concentrated0, uint256 concentrated1) = concentratedPosition();

        if (token0IsDeposit) {
            totalDeposit = 
                protected0 +
                concentrated0 +
                amountDeposit;
            totalQuote = 
                protected1 +
                concentrated1 +
                amountQuote;
        } else {
            totalDeposit = 
                protected1 +
                concentrated1 +
                amountDeposit;
            totalQuote = 
                protected0 +
                concentrated0 +
                amountQuote;
        }
        uint256 depositAsQuote = UD60x18.unwrap(ud(totalDeposit).mul(ud(price)));
        value = depositAsQuote + totalQuote;
    }

    /**
     @notice A portion of the deposit tokens on hand is protected and does not participate in liquidity.
     @return amount0 Protected token0 tokens.
     @return amount1 Protected token0 tokens.
     */
    function protectedPosition() public override view returns (uint256 amount0, uint256 amount1) {
        amount0 = app.protected0;
        amount1 = app.protected1;
    }

    /**
     @notice A portiom of the deposit tokens on hand participates concentrated liquidity.
     @return amount0 token0 tokens in the dynamicaly allocated concentrated liquidity position. 
     @return amount1 token1 tokens in the dynamicaly allocated concentrated liquidity position. 
     */
    function concentratedPosition() public override view returns (uint256 amount0, uint256 amount1) {
        amount0 = ERC20(token0).balanceOf(address(this)) - app.protected0;
        amount1 = ERC20(token1).balanceOf(address(this)) - app.protected1;
    }

    /**
     @notice This contract owns a position in a Uv3 pool, the flex position. 
     @return amountDeposit The amount of deposit tokens in the flex position liquidity. 
     @return amountQuote The amount of quote tokens  in the flex position liquidity. 
     */
    function flexPosition() public override view returns (uint256 amountDeposit, uint256 amountQuote) {
        // TODO /1000, *1000 - temporary patch until the math is fixed on lower levels
        int24 tickMin = tMin();
        int24 tickMax = tMax();
        (uint128 liquidity, , ) = _flexPosition(tickMin, tickMax);
        (uint256 amount0, uint256 amount1) = SoloUV3Math.getAmountsForLiquidity(
            SoloMath.getSqrtRatioAtTick(currentTick()),
            SoloMath.getSqrtRatioAtTick(tickMin),
            SoloMath.getSqrtRatioAtTick(tickMax),
            liquidity / 1000
        );
        amountDeposit = (token0IsDeposit) ? amount0 * 1000: amount1 * 1000;
        amountQuote = (token0IsDeposit) ? amount1 * 1000 : amount0 * 1000;
    }

    function tMin() public override view returns (int24 tick) {
        tick = int24(SD59x18.unwrap(app.tMin));
    }

    function tMax() public override view returns (int24 tick) {
        tick = int24(SD59x18.unwrap(app.tMax));
    }

    /**
     @notice Lookup function for debug purposes. 
     @return app_
     */
    function lookupState() public view returns (SoloMath.SoloState memory app_) {
        app_ = app;
    }

    /**
     @notice General lookup function for debug purposes. 
     @return ctx
     */
    function lookupContext() public view returns (
        SoloMath.SoloContext memory ctx,
        uint256 spot_,
        int24 cTick_,
        int24 tickMin,
        int24 tickMax,
        uint160 sMin,
        uint160 sMax,
        uint128 liquidity,
        uint256 t0,
        uint256 t1) {
        tickMin = tMin();
        tickMax = tMax();
        ctx = getContext();
        spot_ = pool.spot(
                depositToken(),
                quoteToken(),
                1
            );
        cTick_ = currentTick();
        sMin = uint160(UD60x18.unwrap(app.sqrtPMin));
        sMax = uint160(UD60x18.unwrap(app.sqrtPMax));
        (liquidity, ,) = _flexPosition(tickMin, tickMax);
        t0 = 0;
        t1 = 0;
    }

    /**
     @notice Calculates liquidity amount for the given shares.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param shares number of shares
     */
    function _liquidityForShares(
        int24 tickLower,
        int24 tickUpper,
        uint256 shares
    ) internal view returns (uint128) {
        (uint128 position, , ) = _flexPosition(tickLower, tickUpper);
        return (position * shares / totalSupply())._uint128Safe();
    }

    /**
     @notice Returns information about the liquidity position.
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param liquidity liquidity amount
     @param tokensOwed0 amount of token0 owed to the owner of the position
     @param tokensOwed1 amount of token1 owed to the owner of the position
     */
    function _flexPosition(int24 tickLower, int24 tickUpper)
        internal
        view
        returns (
            uint128 liquidity,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        )
    {
        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), tickLower, tickUpper)
        );
        (liquidity, , , tokensOwed0, tokensOwed1) = IUniswapV3Pool(pool)
            .positions(positionKey);
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override {
        SoloMath.uniswapV3MintCallback(
            pool,
            token0,
            token1,
            amount0,
            amount1,
            data
        );
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external override {
        SoloMath.uniswapV3SwapCallback(
            pool,
            token0,
            token1,
            amount0Delta,
            amount1Delta,
            data
        );
    }

}
