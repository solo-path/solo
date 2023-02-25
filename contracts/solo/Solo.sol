// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.14;

import { ISolo } from "../interfaces/ISolo.sol";
import { IUniswapV3Factory } from "../interfaces/IUniswapV3Factory.sol";
import { IUniswapV3MintCallback } from "../interfaces/callback/IUniswapV3MintCallback.sol";
import { IUniswapV3SwapCallback } from "../interfaces/callback/IUniswapV3SwapCallback.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Solo is ISolo, ERC20, ReentrancyGuard {

    using SafeERC20 for ERC20;

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
        uint256 price
    ) external override {
        // TODO
        // put both tokens in and set the price
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

    function withdraw(uint256 lpAmount, address to) public returns (uint256 amountDeposit, uint256 amountQuote) {
        return (0, 0);
    }

    function swapExactInput(uint256 amount0, uint256 amount1) external override 
        returns (uint256 output0, uint256 output1) {

        return (0, 0);
    }

}
