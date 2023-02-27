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

contract Solo is ISolo, 
    ERC20,
    IUniswapV3MintCallback,
    IUniswapV3SwapCallback, 
    Initializable, 
    ReentrancyGuard {

    using SafeERC20 for ERC20;
    using SafeERC20 for IERC20;

    address private constant ADDRESS_NULL = address(0);

    address public immutable pool;
    address public immutable token0;
    address public immutable token1;
    bool public immutable token0IsDeposit;

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
        return (0, 0);
    }

    function swapExactInput(
        uint256 amount0, 
        uint256 amount1
    ) external override nonReentrant 
        returns (uint256 output0, uint256 output1) {

        return (0, 0);
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
                SoloUV3Math.getSqrtRatioAtTick(tickLower),
                SoloUV3Math.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
    }

    /**
     @notice returns equivalent _tokenOut for _amountIn, _tokenIn using TWAP price
     @param _twapPeriod the averaging time period
     @param _amountIn amount in _tokenIn
     @param amountOut equivalent anount in _tokenOut
     */
    function fetchTwap(
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
