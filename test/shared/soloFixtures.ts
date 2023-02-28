import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
// might be needed
// import { MockTimeUniswapV3Pool } from '../../typechain/MockTimeUniswapV3Pool'
// import { MockTimeUniswapV3PoolDeployer } from '../../typechain/MockTimeUniswapV3PoolDeployer'
import { Fixture } from 'ethereum-waffle'

import {
  SoloFactory,
  SoloERC20,
  UniswapV3Factory
} from "../../typechain";

interface SoloFixture {
  soloFactory: SoloFactory,
  uv3Factory: UniswapV3Factory // for read-only ops
  weth: SoloERC20
  usdc: SoloERC20
}

interface SoloFactoryFixture {
  soloFactory: SoloFactory
}

interface UniswapV3FactoryFixture {
  uv3Factory: UniswapV3Factory
}

interface TokensFixture {
  weth: SoloERC20
  usdc: SoloERC20
}

async function soloFactoryFixture(uniswapV3Factory: UniswapV3Factory): Promise<SoloFactoryFixture> {
  const SoloUV3MathLib = await ethers.getContractFactory("SoloUV3Math");
  const soloUV3MathLib = await SoloUV3MathLib.deploy();
  await soloUV3MathLib.deployed();

  const SoloMathLib = await ethers.getContractFactory("SoloMath", {
    libraries: {
      SoloUV3Math: soloUV3MathLib.address,
    },
  });
  const soloMathLib = await SoloMathLib.deploy();
  await soloMathLib.deployed();

  const soloFactoryFactory = await ethers.getContractFactory('SoloFactory', {
    libraries: {
      SoloMath:  soloMathLib.address, 
      SoloUV3Math: soloUV3MathLib.address
    }
  })
  const soloFactory = (await soloFactoryFactory.deploy(uniswapV3Factory.address)) as SoloFactory;
  return { soloFactory }
}

async function uniswapV3FactoryFixture(): Promise<UniswapV3FactoryFixture> {
  const factoryFactory = await ethers.getContractFactory('UniswapV3Factory')
  const uv3Factory = (await factoryFactory.deploy()) as UniswapV3Factory
  return { uv3Factory }
}

async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('SoloERC20')
  const weth = (await tokenFactory.deploy("WETH","WETH",18,BigNumber.from(2).pow(255))) as SoloERC20
  const usdc = (await tokenFactory.deploy("USDC","USDC",18,BigNumber.from(2).pow(255))) as SoloERC20
  return { weth, usdc }
}

export const soloFixture: Fixture<SoloFixture> = async function (): Promise<SoloFixture> {
  const { uv3Factory } = await uniswapV3FactoryFixture()
  const { soloFactory } = await soloFactoryFixture(uv3Factory);
  const { weth, usdc } = await tokensFixture()

  return {
      soloFactory,
      uv3Factory,
      weth,
      usdc
  }
}

