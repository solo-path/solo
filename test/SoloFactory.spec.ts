import { BigNumber } from 'ethers'
import { ethers, waffle } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { soloFixture } from "./shared/soloFixtures";
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

// Probably don't need these two (from TickMath test).
import { encodePriceSqrt, MIN_SQRT_RATIO, MAX_SQRT_RATIO } from './shared/utilities'
import Decimal from 'decimal.js'

import {
  SoloFactory,
  Solo,
  TestERC20,
  UniswapV3Factory, // use as read-only
  UniswapV3Pool // use as read-only
} from "../typechain";

const MIN_TICK = -887272
const MAX_TICK = 887272

const ONE = BigNumber.from(10).pow(18);
const ZERO = BigNumber.from(0);

const namedAccounts: { [name: string]: number } = {
  admin: 0,
  alice: 1,
  bob: 2,
  attacker: 3
};

describe('SoloFactory', () => {

  // wallets used in this test
  const provider = waffle.provider;
  const wallets = provider.getWallets();
  const adminWallet = wallets[namedAccounts["admin"]];

  // prepare contracts with interfaces
  let soloFactory: SoloFactory;
  let uv3Factory: UniswapV3Factory;

  // fixture loader
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  before('deploy SoloFactoryTest', async () => {
    loadFixture = createFixtureLoader([adminWallet], provider);
    const fixture = await loadFixture(soloFixture);
    soloFactory= fixture.soloFactory;
    uv3Factory = fixture.uv3Factory;
  })

  describe('check readiness', () => {
    it('ready to test', async () => {
      await expect(await soloFactory.poolFactory()).to.equal(uv3Factory.address)
    });
  });

});
