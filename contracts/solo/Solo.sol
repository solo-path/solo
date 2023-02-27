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
    uint32 private constant FIVE_MINUTES = 5 minutes;

    address public immutable pool;
    address public immutable token0;
    address public immutable token1;
    bool public immutable token0IsDeposit;

    UD60x18 public bMin;
    SD59x18 public tPct;
    UD60x18 public s;
    UD60x18 public fee;
    UD60x18 public dPct;
    UD60x18 public fPct;
    UD60x18 public rPct;

    // state of the pool with all positions
    SoloMath.SoloState private app;

    constructor(
        address uv3PoolFactory_,
        address tokenA_,
        address tokenB_,
        bool tokenAIsDeposit_,
        uint24 fee_,
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

        bool tokenAIsToken0 = tokenA_ < tokenB_;
        token0IsDeposit = (tokenAIsToken0 && tokenAIsDeposit_) || (!tokenAIsToken0 && !tokenAIsDeposit_);

        token0 = tokenAIsToken0 ? tokenA_ : tokenB_;
        token1 = tokenAIsToken0 ? tokenB_ : tokenA_;
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

    function firstDeposit(
        uint256 amountDeposit,
        uint256 amountQuote,
        int24 ticksRange,
        uint256 price,
        address to
    ) external override {
        // require that the pool has no money
        // nothing to protected position
        // Some quote tokens to flex position and some to concentrated.
        // Some deposit tokens to flex and some to concentrated.
        // Same formulation as regular deposit. (to calculate LPs)
        // Set the price in Uv3 pool.

        uint256 balanceToken0 = uint128(ERC20(token0).balanceOf(pool));
        uint256 balanceToken1 = uint128(ERC20(token1).balanceOf(pool));
        require(balanceToken0 == 0 && balanceToken1 == 0, "not empty");

        // initialize the underlying pool 
        uint160 sqrtPrice = uint160(UD60x18.unwrap(ud(price).sqrt()));
        IUniswapV3Pool(pool).initialize(sqrtPrice);

        // tC is calculated here
        SoloMath.SoloContext memory ctx = getContext();

        app.tMin = ctx.tC.sub(sd(ticksRange));
        app.tMax = ctx.tC.add(sd(ticksRange));

        // this check is needed, but commented out for for to reduce contract size            
        require(app.tMin.gte(SoloMath.minTick()) && app.tMax.lte(SoloMath.maxTick()), "large range");

        // get users funds
        ERC20(depositToken()).safeTransferFrom(msg.sender, address(this), amountDeposit);
        ERC20(quoteToken()).safeTransferFrom(msg.sender, address(this), amountQuote);

        app.x = ud(amountDeposit);
        app.y = ud(amountQuote);

        // set proper fX and fY (so some amount if set aside for cX and cY)
        (ctx.fX, ctx.fY) = app.computeFxFy(ctx, fPct);

        // set the Flex position
        putFlexPosition(ctx);

        UD60x18 valueOfDeposit = ud(amountQuote).add(ud(amountDeposit).mul(ud(price)));

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

        UD60x18 spotPrice = ud(spot(depositToken(), quoteToken(), ONE));
        UD60x18 twapPrice = ud(twap(pool, depositToken(), quoteToken(), FIVE_MINUTES, ONE));
        UD60x18 offeredPrice = SoloMath.min(spotPrice, twapPrice);

        UD60x18 toProtected = dPct.mul(ud(amountDeposit));

        // if the difference between the spot price and the 15 minute TWAP is more than 5%
        // TODO the check above

        // or the price change in the block is more than twice the trading fee
        // TODO the check above

        ERC20(depositToken()).safeTransferFrom(msg.sender, address(this), amountDeposit);

        if (token0IsDeposit) {
            app.protected0 = app.protected0 + UD60x18.unwrap(toProtected);
        } else {
            app.protected1 = app.protected1 + UD60x18.unwrap(toProtected);
        }
 
        UD60x18 valueOfDeposit = offeredPrice.mul(ud(amountDeposit));
        UD60x18 valueIncreasePercent = 
            valueOfDeposit.div(
                ud(capitalAsQuoteTokens(UD60x18.unwrap(SoloMath.max(spotPrice, twapPrice)))).add(valueOfDeposit)
            );
 
        UD60x18 lpAmount = ud(totalSupply()).mul(valueIncreasePercent);
        lpTokens = UD60x18.unwrap(lpAmount);
        _mint(to, lpTokens);

        // The allocation of tokens between the Flex position and the Concentrated position is reassessed after deposits 
        // and before trades.
        if(bMin.lt(ud(block.number - app.blockNumber))) {
            SoloMath.SoloContext memory ctx = getContext();            
            (ctx.fX, ctx.fY) = app.computeFxFy(ctx, fPct);
            pullFlexPosition();
            putFlexPosition(ctx);
        }

        // TODO increase app.x and app.y ??
    }

    /**
     @param lpAmount Number of liquidity tokens to redeem as pool assets
     @param to Address to which redeemed pool assets are sent
     @return amountDeposit Amount of deposit tokens redeemed by the submitted liquidity tokens
     @return amountQuote Amount of quote tokens redeemed by the submitted liquidity tokens
     */

    function withdraw(
        uint256 lpAmount, 
        address to
    ) external override nonReentrant returns (uint256 amountDeposit, uint256 amountQuote) {

        transferFrom(msg.sender, address(this), lpAmount);
        _burn(address(this), lpAmount);

        uint256 lpSupply = totalSupply();

        // Withdraw ratio amount of liquidity

        int24 tickLower = int24(SD59x18.unwrap(app.tMin));
        int24 tickUpper = int24(SD59x18.unwrap(app.tMax));

        (uint256 amount0, uint256 amount1) = _burnLiquidity(
            _liquidityForShares(tickLower, tickUpper, lpAmount),
            tickLower,
            tickUpper,
            address(this), 
            false);

        amountDeposit = (token0IsDeposit) ? amount0 : amount1;
        amountQuote = (token0IsDeposit) ? amount1 : amount0;

        // Withdraw ratio amount of protected and concentrated

        (uint256 protected0, uint256 protected1) = protectedPosition();
        (uint256 concentrated0, uint256 concentrated1) = concentratedPosition();

        if (token0IsDeposit) {
            amountDeposit += lpAmount * protected0 / lpSupply;
            amountDeposit += lpAmount * concentrated0 / lpSupply;
        } else {
            amountDeposit += lpAmount * protected1 / lpSupply;
            amountDeposit += lpAmount * concentrated1 / lpSupply;
        }

        // send sums to user
        ERC20(depositToken()).safeTransfer(to, amountDeposit);
        ERC20(quoteToken()).safeTransfer(to, amountQuote);

        // TODO reduce app.x and app.y ??
    }

    function swapExactInput(
        uint256 amount0, 
        uint256 amount1
    ) external override nonReentrant 
        returns (uint256 output0, uint256 output1) {

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
            ERC20(token0).safeTransferFrom(_msgSender(), address(this), amount0) :
            ERC20(token1).safeTransferFrom(_msgSender(), address(this), amount1);
        
        // if(amount0 == 0 && amount1 == 0) revert("not possible?")

        // The following steps are coordinated in tokensUsed() below.

        /*
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

        if (ts.resetsConcentratedPosition) {
            // ... all swap to flex position (amountX, amountY) execute reset, exit
            (ts.fox, ts.foy) = IUniswapV3Pool(pool).swap(
                address(this),
                ts.xForY,
                (ts.xForY) ? int256(amount0) : int256(amount1),
                (ts.xForY) ? 
                      SoloUV3Math.MIN_SQRT_RATIO + 1
                    : SoloUV3Math.MAX_SQRT_RATIO - 1,
                abi.encode(address(this))
            );
            app.resetConcentratedPosition();
            if(ts.xForY) {
                ERC20(token1).transfer(msg.sender, uint256(ts.foy));
            } else {
                ERC20(token0).transfer(msg.sender, uint256(ts.fox));
            }
            return (uint256(ts.fox), uint256(ts.foy));
        }

        /*
        Execute swap control flow for the partial trade against the Flex position using FAx or FAy amount from Step 5.
        */
       
        // One of these will be positive and exact - amount tokens received.

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

        ts.concentratedSwapPrice = ((spot(depositToken(), quoteToken(), ONE)))._uint160Safe();

        // Step 7
        // Formula 4.30

        if (ts.xForY) {
            UD60x18 spotXForY = ud(ts.concentratedSwapPrice);
            // Formula 4.29
            ts.coy = ts.cax.mul(spotXForY);
            // Formula 4.30
            ts.oy = SoloMath.min(ud(uint256(ts.foy)).add(ts.coy), ts.acy);
            // oy + foy to trader
            ERC20(token1).safeTransfer(msg.sender, UD60x18.unwrap(ts.oy)); // Y is token1
        } else {
            UD60x18 spotYForX = SoloMath.one().div(ud(ts.concentratedSwapPrice));
            // Formula 4.29
            ts.cox = ts.cax.div(spotYForX);
            // Formula 4.30
            ts.ox = SoloMath.min(ud(uint256(ts.fox)).add(ts.cox), ts.acx);
            // ox + fox to trader
            ERC20(token0).safeTransfer(msg.sender, UD60x18.unwrap(ts.ox)); // X is token0
        }

        return (UD60x18.unwrap(ts.ox), UD60x18.unwrap(ts.oy));
    }

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

        return (ts);
    }

    function depositToken() public view returns (address token) {
        token = (token0IsDeposit) ? token0 : token1;
    }

    function quoteToken() public view returns (address token) {
        token = (token0IsDeposit) ? token1 : token0;
    }

    function currentTick() public view returns (int24 tick) {
        tick = pool.currentTick();
    }

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
            // Rebalancing is avoided if the number of blocks since the high volatility trigger is less than block delay.
            if(bMin.lt(ud(block.number - app.blockNumber))) {
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
        (amount0, amount1) = _burnLiquidity(
            uint128(ERC20(pool).balanceOf(address(this))),
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

        uint256 liquidity = _liquidityForAmounts(
            pool,
            tickLower,
            tickUpper,
            UD60x18.unwrap(ctx.fX),
            UD60x18.unwrap(ctx.fY)
        );

        (amount0, amount1) = _mintLiquidity(
            tickLower, 
            tickUpper, 
            uint128(liquidity));
    }

    function getContext() public view returns (SoloMath.SoloContext memory context) {
        
        UD60x18 uninitialized;

        (uint160 sqrtP, , , , , , ) = IUniswapV3Pool(pool).slot0();

        context = SoloMath.SoloContext({
            cX: uninitialized,
            cY: uninitialized,
            fX: uninitialized,
            fY: uninitialized,
            sqrtP: ud(uint256(sqrtP)),
            tC: sd(pool.currentTick())
        });
    }

    /**
     @notice Calculate total value of the pool in quote tokens.
     @return value total value of the pool
     */
    function capitalAsQuoteTokens(uint256 price) public view returns (uint256 value) {
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
    function protectedPosition() public view returns (uint256 amount0, uint256 amount1) {
        amount0 = app.protected0;
        amount1 = app.protected1;
    }

    /**
     @notice A portiom of the deposit tokens on hand participates concentrated liquidity.
     @return amount0 token0 tokens in the dynamicaly allocated concentrated liquidity position. 
     @return amount1 token1 tokens in the dynamicaly allocated concentrated liquidity position. 
     */
    function concentratedPosition() public view returns (uint256 amount0, uint256 amount1) {
        amount0 = ERC20(token0).balanceOf(address(this)) - app.protected0;
        amount1 = ERC20(token1).balanceOf(address(this)) - app.protected1;
    }

    /**
     @notice This contract owns a position in a Uv3 pool, the flex position. 
     @return amountDeposit The amount of deposit tokens in the flex position liquidity. 
     @return amountQuote The amount of quote tokens  in the flex position liquidity. 
     */
    function flexPosition() public view returns (uint256 amountDeposit, uint256 amountQuote) {
        int24 tickMin = int24(SD59x18.unwrap(app.tMin));
        int24 tickMax = int24(SD59x18.unwrap(app.tMax));
        (uint256 amount0, uint256 amount1) = SoloUV3Math.getAmountsForLiquidity(
            spot(
                depositToken(),
                quoteToken(),
                1
            ),
            SoloMath.getSqrtRatioAtTick(tickMin),
            SoloMath.getSqrtRatioAtTick(tickMax),
            (ERC20(pool).balanceOf(address(this)))._uint128Safe()
        );
        amountDeposit = (token0IsDeposit) ? amount0 : amount1;
        amountQuote = (token0IsDeposit) ? amount1 : amount0;
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
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) internal returns (uint256 amount0, uint256 amount1) {
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
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        address to,
        bool collectAll
    ) internal returns (uint256 amount0, uint256 amount1) {
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
                : owed0._uint128Safe();
            uint128 collect1 = collectAll
                ? type(uint128).max
                : owed1._uint128Safe();
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
     @notice Returns current price tick
     @param tick Uniswap pool's current price tick
     */
    function currentTick(address pool) public view returns (int24 tick) {
        (, int24 tick_, , , , , bool unlocked_) = IUniswapV3Pool(pool).slot0();
        require(unlocked_, "IV.currentTick: the pool is locked");
        tick = tick_;
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

    /**
     @notice Calculates amount of liquidity in a position for given token0 and token1 amounts
     @param tickLower The lower tick of the liquidity position
     @param tickUpper The upper tick of the liquidity position
     @param amount0 token0 amount
     @param amount1 token1 amount
     */
    function _liquidityForAmounts(
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
                SoloUV3Math.getSqrtRatioAtTick(tickLower),
                SoloUV3Math.getSqrtRatioAtTick(tickUpper),
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
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint160 amountOut) { 
        return
            (
                SoloUV3Math.getQuoteAtTick(
                    currentTick(),
                    SoloUV3Math.toUint128(amountIn),
                    tokenIn,
                    tokenOut
                )
            )._uint128Safe();
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

}
