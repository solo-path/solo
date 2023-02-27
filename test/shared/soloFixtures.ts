import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
// might be needed
// import { MockTimeUniswapV3Pool } from '../../typechain/MockTimeUniswapV3Pool'
// import { MockTimeUniswapV3PoolDeployer } from '../../typechain/MockTimeUniswapV3PoolDeployer'
import { Fixture } from 'ethereum-waffle'

import {
  SoloFactory,
  TestERC20,
  UniswapV3Factory
} from "../../typechain";

interface SoloFixture {
  soloFactory: SoloFactory,
  uv3Factory: UniswapV3Factory // for read-only ops
  weth: TestERC20
  usdc: TestERC20
}

interface SoloFactoryFixture {
  soloFactory: SoloFactory
}

interface UniswapV3FactoryFixture {
  uv3Factory: UniswapV3Factory
}

interface TokensFixture {
  weth: TestERC20
  usdc: TestERC20
}

async function soloFactoryFixture(uniswapV3Factory: UniswapV3Factory): Promise<SoloFactoryFixture> {
  const soloFactoryFactory = await ethers.getContractFactory('SoloFactory')
  const soloFactory = (await soloFactoryFactory.deploy(uniswapV3Factory.address)) as SoloFactory;
  return { soloFactory }
}

async function uniswapV3FactoryFixture(): Promise<UniswapV3FactoryFixture> {
  const factoryFactory = await ethers.getContractFactory('UniswapV3Factory')
  const uv3Factory = (await factoryFactory.deploy()) as UniswapV3Factory
  return { uv3Factory }
}

async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('TestERC20')
  const weth = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestERC20
  const usdc = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestERC20
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

