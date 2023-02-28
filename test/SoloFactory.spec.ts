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
  UniswapV3Pool, // use as read-only
  ERC20,
  ISolo
} from "../typechain";

const MIN_TICK = -887272
const MAX_TICK = 887272

const ONE = BigNumber.from(10).pow(18);
const OFF3 = BigNumber.from(10).pow(15);
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
  let weth: TestERC20;
  let usdc: TestERC20;

  // fixture loader
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  before('deploy SoloFactoryTest', async () => {
    loadFixture = createFixtureLoader([adminWallet], provider);
    const fixture = await loadFixture(soloFixture);
    soloFactory= fixture.soloFactory;
    uv3Factory = fixture.uv3Factory;
    weth = fixture.weth;
    usdc = fixture.usdc;
  })

  describe('check readiness', () => {
    it('ready to test', async () => {
      await expect(await soloFactory.poolFactory()).to.equal(uv3Factory.address)
    });
  });

  describe('create and initialize pool', () => {
    const [wallet, alice, bob, carol, other,
      user0, user1, user2, user3, user4] = waffle.provider.getWallets()

    it('create pool', async () => {

      /*
      function createSoloPool(
        address tokenX,
        address tokenY,
        bool xIsDeposit,
        uint24 fee,
        UD60x18 bMin,
        SD59x18 tPct,
        UD60x18 s,
        UD60x18 dPct,
        UD60x18 fPct,
        UD60x18 rPct
      */

      await soloFactory.createSoloPool(
        weth.address,
        usdc.address,
        false,
        ONE.div(100), // 1%
        ONE.mul(20), // 20 blocks
        ONE.mul(50).div(100), // 50%
        ONE.mul(1500), // 1500 speed
        ONE.mul(50).div(100), // 50%
        ONE.mul(20).div(100), // 20%
        ONE.mul(10).div(100), // 10%
      );

      const poolAddress = (await soloFactory.deployedPools(0));
      const soloPool = (await ethers.getContractAt('Solo', poolAddress)) as Solo;

      console.log(soloPool.address);
      await expect(await soloPool.bMin()).to.equal(ONE.mul(20));
      await expect(await soloPool.token0()).to.equal(usdc.address);
      await expect(await soloPool.token1()).to.equal(weth.address);
      await expect(await soloPool.token0IsDeposit()).to.equal(true);
      await expect(await soloPool.s()).to.equal(ONE.mul(1500));
      await expect(await soloPool.tPct()).to.equal(ONE.mul(50).div(100));
      await expect(await soloPool.dPct()).to.equal(ONE.mul(50).div(100));
      await expect(await soloPool.fPct()).to.equal(ONE.mul(20).div(100));
      await expect(await soloPool.rPct()).to.equal(ONE.mul(10).div(100));

      await expect(await soloPool.name()).to.equal("Solo USDC-WETH:50");
      await expect(await soloPool.symbol()).to.equal("USDC-WETH:50");

    });

    it('first deposit', async () => {
      const poolAddress = (await soloFactory.deployedPools(0));
      const soloPool = (await ethers.getContractAt('Solo', poolAddress)) as Solo;
      console.log(soloPool.address);

      await weth.approve(soloPool.address, ONE.mul(1000));
      await usdc.approve(soloPool.address, ONE.mul(1000));

      await soloPool.firstDeposit(ONE.mul(1000),ONE.mul(1000),5000,ONE.mul(1));

      //let fp = await soloPool.ctx_();
      //console.log(fp);

      let res = await soloPool.protectedPosition();
      // nothing in protected position
      expect(res.amount0).to.equal(ZERO);
      expect(res.amount1).to.equal(ZERO);
      //console.log(res);
      res = await soloPool.concentratedPosition();
      // 20% taken for flex position
      expect(res.amount0.div(OFF3).toNumber()).to.be.closeTo(800000,1);
      expect(res.amount1.div(OFF3).toNumber()).to.be.closeTo(800000,1);
      //console.log(res);

      //let cres = await soloPool.lookupContext();
      //console.log(cres);
      
      let fres = await soloPool.flexPosition();
      //20% taken for flex position
      expect(fres.amountDeposit.div(OFF3).toNumber()).to.be.closeTo(200000,1);
      expect(fres.amountQuote.div(OFF3).toNumber()).to.be.closeTo(200000,1);
      //console.log(fres);

      let sres = await soloPool.lookupState();
      expect(sres.x).to.equal(ONE.mul(1000));
      expect(sres.y).to.equal(ONE.mul(1000));
      expect(sres.tMin).to.equal(-5000);
      expect(sres.tMax).to.equal(5000);
      //console.log(sres);

    });

  });

});
