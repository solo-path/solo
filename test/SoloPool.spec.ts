import { BigNumber } from 'ethers'
import { ethers, waffle } from "hardhat";
import { createFixtureLoader } from "ethereum-waffle";
import { soloFixture } from "./shared/soloFixtures";
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

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

describe('SoloPool', () => {

  // wallets used in this test
  const provider = waffle.provider;
  const wallets = provider.getWallets();
  const adminWallet = wallets[namedAccounts["admin"]];

  // prepare contracts with interfaces
  let soloFactory: SoloFactory;
  let uv3Factory: UniswapV3Factory;
  let weth: TestERC20;
  let usdc: TestERC20;
  let soloPool: Solo;

  // fixture loader
  let loadFixture: ReturnType<typeof createFixtureLoader>;

  before('deploy SoloFactory and Solo pool instance', async () => {
    loadFixture = createFixtureLoader([adminWallet], provider);
    const fixture = await loadFixture(soloFixture);
    soloFactory= fixture.soloFactory;
    uv3Factory = fixture.uv3Factory;
    weth = fixture.weth;
    usdc = fixture.usdc;

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
    soloPool = (await ethers.getContractAt('Solo', poolAddress)) as Solo;
    console.log(soloPool.address);

    await weth.approve(soloPool.address, ONE.mul(1000));
    await usdc.approve(soloPool.address, ONE.mul(1000));

    await soloPool.firstDeposit(ONE.mul(1000),ONE.mul(1000),5000,ONE.mul(1));
})

  describe('liquidity provider', () => {
    const [wallet, alice, bob, carol, other,
      user0, user1, user2, user3, user4] = waffle.provider.getWallets()
    const walletSigner = waffle.provider.getSigner(wallet.address);

    async function mineNBlocks(n: number) {
      for (let index = 0; index < n; index++) {
        await ethers.provider.send('evm_mine', []);
      }
    }

    it('deposit', async () => {
      let start_balance = await soloPool.balanceOf(wallet.address)
      console.log(start_balance.toString());
      expect(start_balance).to.equal(ONE.mul(2000));

      //let ares1 = await soloPool.lookupState();
      //console.log(ares1);

      await mineNBlocks(500); // so rebalance should be considered 

      //let cres = await soloPool.lookupContext();
      //console.log(cres);

      await usdc.approve(soloPool.address, ONE.mul(2000));
      await soloPool.connect(wallet).deposit(ONE.mul(2000), wallet.address);

      let end_balance = await soloPool.balanceOf(wallet.address)
      console.log(end_balance.toString());
      expect(end_balance).to.equal(ONE.mul(4000));

      // P - 1000/0, C - 1800/800, F - 200/200
      let res = await soloPool.protectedPosition();
      expect(res.amount0).to.equal(ONE.mul(1000));
      expect(res.amount1).to.equal(ZERO);
      //console.log(res);
      res = await soloPool.concentratedPosition();
      expect(res.amount0.div(OFF3).toNumber()).to.be.closeTo(1800000,1);
      expect(res.amount1.div(OFF3).toNumber()).to.be.closeTo(800000,1);
      //console.log(res);
      let fres = await soloPool.flexPosition();
      expect(fres.amountDeposit.div(OFF3).toNumber()).to.be.closeTo(200000,1);
      expect(fres.amountQuote.div(OFF3).toNumber()).to.be.closeTo(200000,1);
      //console.log(fres);

      //let cres = await soloPool.lookupContext();
      //console.log(cres);

      let ares = await soloPool.lookupState();
      expect(ares.x).to.equal(ONE.mul(2000));
      expect(ares.y).to.equal(ONE.mul(1000));
    });

    it('withdraw', async () => {
      let start_balance = await soloPool.balanceOf(wallet.address)
      console.log(start_balance.toString());
      expect(start_balance).to.equal(ONE.mul(4000));

      // P - 1000/0, C - 1800/800, F - 200/200

      //let res = await soloPool.concentratedPosition();
      //console.log(res);

      let usdc_balance_start = await usdc.balanceOf(wallet.address)
      let weth_balance_start = await weth.balanceOf(wallet.address)

      await soloPool.withdraw(ONE.mul(1000), wallet.address);

      let end_balance = await soloPool.balanceOf(wallet.address)
      console.log(end_balance.toString());
      expect(end_balance).to.equal(ONE.mul(3000));

      // P - 750/0, C - 1350/600, F - 150/150

      let res = await soloPool.protectedPosition();
      expect(res.amount0).to.equal(ONE.mul(750));
      expect(res.amount1).to.equal(ZERO);
      //console.log(res);
      res = await soloPool.concentratedPosition();
      expect(res.amount0.div(OFF3).toNumber()).to.be.closeTo(1350000,1);
      expect(res.amount1.div(OFF3).toNumber()).to.be.closeTo(600000,1);
      //console.log(res);
      let fres = await soloPool.flexPosition();
      expect(fres.amountDeposit.div(OFF3).toNumber()).to.be.closeTo(150000,1);
      expect(fres.amountQuote.div(OFF3).toNumber()).to.be.closeTo(150000,1);
      //console.log(fres);

      //let cres = await soloPool.lookupContext();
      //console.log(cres);

      let ares = await soloPool.lookupState();
      expect(ares.x.div(OFF3).toNumber()).to.be.closeTo(1500000,1);
      expect(ares.y.div(OFF3).toNumber()).to.be.closeTo(750000,1);

      let usdc_balance_end = await usdc.balanceOf(wallet.address)
      let weth_balance_end = await weth.balanceOf(wallet.address)
      expect(usdc_balance_end.sub(usdc_balance_start).div(OFF3).toNumber()).to.be.closeTo(750000,1);
      expect(weth_balance_end.sub(weth_balance_start).div(OFF3).toNumber()).to.be.closeTo(250000,1);
    });

  });

});
