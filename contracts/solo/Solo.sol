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

    address public immutable pool;
    address public immutable token0;
    address public immutable token1;
    bool public immutable token0IsDeposit;

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
        token0IsDeposit = tokenAIsToken0 && tokenAIsDeposit_;

        token0 = tokenAIsToken0 ? tokenA_ : tokenB_;
        token1 = tokenAIsToken0 ? tokenB_ : tokenA_;
    }

    function firstDeposit(
        uint256 amountDeposit,
        uint256 amountQuote,
        int24 ticksRange,
        uint256 price,
        address to
    ) external override {
        // TODO
        // require that the pool has no money
        // nothing to protected position
        // Some quote tokens to flex position and some to concentrated.
        // Some deposit tokens to flex and some to concentrated.
        // Same formulation as regular deposit. (to calculate LPs)
        // Set the price in Uv3 pool.
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
        lpTokens = 0;
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

        return (0, 0);
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
