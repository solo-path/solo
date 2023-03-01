import { BigNumber, Wallet } from 'ethers'
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

describe('SoloSwap', () => {

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
    await usdc.approve(soloPool.address, ONE.mul(3000));

    await soloPool.firstDeposit(ONE.mul(1000),ONE.mul(1000),5000,ONE.mul(1));

    const [wallet, alice, bob, carol, other,
      user0, user1, user2, user3, user4] = waffle.provider.getWallets()

    await soloPool.deposit(ONE.mul(2000), wallet.address);
    // P - 1000/0, C - 1800/800, F - 200/200

    let end_balance = await soloPool.balanceOf(wallet.address)
    console.log(end_balance.toString());

    await weth.approve(alice.address, ONE.mul(10000));
    await weth.transfer(alice.address,ONE.mul(10000));
    let alice_weth_balance = await weth.balanceOf(alice.address)
    console.log(alice_weth_balance.toString());
})

  describe('trader', () => {
    const [wallet, alice, bob, carol, other,
      user0, user1, user2, user3, user4] = waffle.provider.getWallets()

    async function balances(user: Wallet) {
      let weth_balance = await weth.balanceOf(user.address);
      let usdc_balance = await usdc.balanceOf(user.address);
      return {weth_balance, usdc_balance};
    }

    async function mineNBlocks(n: number) {
      for (let index = 0; index < n; index++) {
        await ethers.provider.send('evm_mine', []);
      }
    }

    it('swap', async () => {
      await mineNBlocks(500); // so rebalance should be considered 

      let bal = await balances(alice);
      //console.log(bal);
      await weth.connect(alice).approve(soloPool.address, ONE.mul(100));
      await soloPool.connect(alice).swapExactInput(0,ONE.mul(3));
      //let res = await soloPool.ts_();
      //console.log(res);
      bal = await balances(alice);
      console.log(bal.usdc_balance.toString());
      console.log(bal.weth_balance.toString());
    });

  });

});
