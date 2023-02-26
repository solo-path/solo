import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { SoloMathTest } from '../typechain/SoloMathTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

import { SoloMath } from '../typechain'

const MIN_TICK = -887272
const MAX_TICK = 887272

const ONE = BigNumber.from(10).pow(18);
const ZERO = BigNumber.from(0);

describe('SoloMath', () => {
    let soloMath: SoloMathTest

  before('deploy SoloMathTest', async () => {
    const SoloMathLib = await ethers.getContractFactory("SoloMath");

    const soloMathLib = await SoloMathLib.deploy();
    await soloMathLib.deployed();
    
    const factory = await ethers.getContractFactory('SoloMathTest', {
      libraries: {
        SoloMath: soloMathLib.address,
      },
    })
    soloMath = (await factory.deploy()) as SoloMathTest
  })

  describe('singulars', () => {
     it('checks constants', async () => {
      await expect(await soloMath.zero()).to.be.equal(0);
      await expect(await soloMath.one()).to.be.equal(BigNumber.from(10).pow(18));
      await expect(await soloMath.two()).to.be.equal(BigNumber.from(10).pow(18).mul(2));
      await expect(await soloMath.four()).to.be.equal(BigNumber.from(10).pow(18).mul(4));
      await expect(await soloMath.oneSigned()).to.be.equal(BigNumber.from(10).pow(18));
      await expect(await soloMath.twoSigned()).to.be.equal(BigNumber.from(10).pow(18).mul(2));
      await expect(await soloMath.minTick()).to.be.equal("-887272000000000000000000");
      await expect(await soloMath.maxTick()).to.be.equal("887272000000000000000000");
    });
  });

  describe('comparisons', () => {
    it('compares equal UD60x18 values', async () => {
      await expect(await soloMath.eq(10, 10)).to.be.equal(true);
      await expect(await soloMath.eq(10, 11)).to.be.equal(false);
    });

    it('compares unequal UD60x18 values', async () => {
      await expect(await soloMath.lt(10, 10)).to.be.equal(false);
      await expect(await soloMath.lt(9, 10)).to.be.equal(true);
      await expect(await soloMath.lt(10, 9)).to.be.equal(false);     

      await expect(await soloMath.lte(10, 10)).to.be.equal(true);
      await expect(await soloMath.lte(9, 10)).to.be.equal(true);
      await expect(await soloMath.lte(10, 9)).to.be.equal(false);     

      await expect(await soloMath.gt(10, 10)).to.be.equal(false);
      await expect(await soloMath.gt(9, 10)).to.be.equal(false);
      await expect(await soloMath.gt(10, 9)).to.be.equal(true);     

      await expect(await soloMath.gte(10, 10)).to.be.equal(true);
      await expect(await soloMath.gte(9, 10)).to.be.equal(false);
      await expect(await soloMath.gte(10, 9)).to.be.equal(true);     
    });
  
    it('min/max of UD60x18 values', async () => {
      await expect(await soloMath.min(10, 10)).to.be.equal(10);
      await expect(await soloMath.min(9, 10)).to.be.equal(9);
      await expect(await soloMath.min(10, 9)).to.be.equal(9);

      await expect(await soloMath.max(10, 10)).to.be.equal(10);
      await expect(await soloMath.max(9, 10)).to.be.equal(10);
      await expect(await soloMath.max(10, 9)).to.be.equal(10);
    });

    it('min/max of SD59x18 values', async () => {
      await expect(await soloMath.minS(-10, -10)).to.be.equal(-10);
      await expect(await soloMath.minS(-9, -10)).to.be.equal(-10);
      await expect(await soloMath.minS(-10, -9)).to.be.equal(-10);

      await expect(await soloMath.maxS(-10, -10)).to.be.equal(-10);
      await expect(await soloMath.maxS(-9, -10)).to.be.equal(-9);
      await expect(await soloMath.maxS(-10, -9)).to.be.equal(-9);
    });

  });

  describe('atomic math', () => {
    it('sq of UD60x18 values', async () => {
      //const msg1 = "sq resulted in 0";

      // TODO doesn't work - need to debug

      // sq of a small number can't be taken
      //await expect(soloMath.sq(BigNumber.from(2000))).to.be.revertedWith(msg1);

      // 1*1=1
      await expect(await soloMath.sq(ONE)).to.be.equal(ONE);
      // 2*2=4
      await expect(await soloMath.sq(ONE.mul(2))).to.be.equal(ONE.mul(4));
    });
  });

  describe('flex position boundaries', () => {
    it('computeFlexPosition', async () => {
      await soloMath.setTminTmax(ONE.mul(-5000),ONE.mul(5000));

      await expect((await soloMath.computeFlexPosition(ONE.mul(0),ONE.div(100)))[0]).to.be.equal(ONE.mul(-5000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(5000),ONE.div(100)))[0]).to.be.equal(ONE.mul(-5000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(-5000),ONE.div(100)))[0]).to.be.equal(ONE.mul(-15000));

      await expect((await soloMath.computeFlexPosition(ONE.mul(0),ONE.div(100)))[1]).to.be.equal(ONE.mul(5000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(-5000),ONE.div(100)))[1]).to.be.equal(ONE.mul(5000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(5000),ONE.div(100)))[1]).to.be.equal(ONE.mul(15000));

      await soloMath.setTminTmax(ONE.mul(5000),ONE.mul(10000));

      await expect((await soloMath.computeFlexPosition(ONE.mul(7500),ONE.div(100)))[0]).to.be.equal(ONE.mul(5000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(5000),ONE.div(100)))[0]).to.be.equal(ONE.mul(0));
      // too far from the boundary (>25)
      await expect((await soloMath.computeFlexPosition(ONE.mul(5030),ONE.div(100)))[0]).to.be.equal(ONE.mul(5000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(9980),ONE.div(100)))[0]).to.be.equal(ONE.mul(5000));
      // too close to the boundary (<25)
      await expect((await soloMath.computeFlexPosition(ONE.mul(5020),ONE.div(100)))[0]).to.be.equal(ONE.mul(40));

      await expect((await soloMath.computeFlexPosition(ONE.mul(7500),ONE.div(100)))[1]).to.be.equal(ONE.mul(10000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(10000),ONE.div(100)))[1]).to.be.equal(ONE.mul(15000));
      // too far from the boundary (>25)
      await expect((await soloMath.computeFlexPosition(ONE.mul(5020),ONE.div(100)))[1]).to.be.equal(ONE.mul(10000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(9970),ONE.div(100)))[1]).to.be.equal(ONE.mul(10000));
      // too close to the boundary (<25)
      await expect((await soloMath.computeFlexPosition(ONE.mul(9980),ONE.div(100)))[1]).to.be.equal(ONE.mul(14960));

      await soloMath.setTminTmax(ONE.mul(-887200),ONE.mul(1000));
      // can't go lower than the min
      await expect((await soloMath.computeFlexPosition(ONE.mul(-887100),ONE.div(200)))[0]).to.be.equal(ONE.mul(-887272));
      await expect((await soloMath.computeFlexPosition(ONE.mul(-887100),ONE.div(200)))[1]).to.be.equal(ONE.mul(1000));

      await soloMath.setTminTmax(ONE.mul(1000),ONE.mul(887200));
      // can't go higher than the max
      await expect((await soloMath.computeFlexPosition(ONE.mul(887100),ONE.div(200)))[0]).to.be.equal(ONE.mul(1000));
      await expect((await soloMath.computeFlexPosition(ONE.mul(887100),ONE.div(200)))[1]).to.be.equal(ONE.mul(887272));
    });

    it('computeTmin', async () => {
      await soloMath.setTminTmax(ONE.mul(-5000),ONE.mul(5000));

      await expect(await soloMath.computeTmin(ONE.mul(0),ONE.div(100))).to.be.equal(ONE.mul(-5000));
      await expect(await soloMath.computeTmin(ONE.mul(5000),ONE.div(100))).to.be.equal(ONE.mul(-5000));
      await expect(await soloMath.computeTmin(ONE.mul(-5000),ONE.div(100))).to.be.equal(ONE.mul(-15000));

      await soloMath.setTminTmax(ONE.mul(5000),ONE.mul(10000));

      await expect(await soloMath.computeTmin(ONE.mul(7500),ONE.div(100))).to.be.equal(ONE.mul(5000));
      await expect(await soloMath.computeTmin(ONE.mul(5000),ONE.div(100))).to.be.equal(ONE.mul(0));
      // too far from the boundary (>25)
      await expect(await soloMath.computeTmin(ONE.mul(5030),ONE.div(100))).to.be.equal(ONE.mul(5000));
      await expect(await soloMath.computeTmin(ONE.mul(9980),ONE.div(100))).to.be.equal(ONE.mul(5000));
      // too close to the boundary (<25)
      await expect(await soloMath.computeTmin(ONE.mul(5020),ONE.div(100))).to.be.equal(ONE.mul(40));

      await soloMath.setTminTmax(ONE.mul(-887200),ONE.mul(1000));
      // can't go lower than the min
      await expect(await soloMath.computeTmin(ONE.mul(-887100),ONE.div(200))).to.be.equal(ONE.mul(-887272));
    });

    it('computeTmax', async () => {
      await soloMath.setTminTmax(ONE.mul(-5000),ONE.mul(5000));

      await expect(await soloMath.computeTmax(ONE.mul(0),ONE.div(100))).to.be.equal(ONE.mul(5000));
      await expect(await soloMath.computeTmax(ONE.mul(-5000),ONE.div(100))).to.be.equal(ONE.mul(5000));
      await expect(await soloMath.computeTmax(ONE.mul(5000),ONE.div(100))).to.be.equal(ONE.mul(15000));

      await soloMath.setTminTmax(ONE.mul(5000),ONE.mul(10000));

      await expect(await soloMath.computeTmax(ONE.mul(7500),ONE.div(100))).to.be.equal(ONE.mul(10000));
      await expect(await soloMath.computeTmax(ONE.mul(10000),ONE.div(100))).to.be.equal(ONE.mul(15000));
      // too far from the boundary (>25)
      await expect(await soloMath.computeTmax(ONE.mul(5020),ONE.div(100))).to.be.equal(ONE.mul(10000));
      await expect(await soloMath.computeTmax(ONE.mul(9970),ONE.div(100))).to.be.equal(ONE.mul(10000));
      // too close to the boundary (<25)
      await expect(await soloMath.computeTmax(ONE.mul(9980),ONE.div(100))).to.be.equal(ONE.mul(14960));

      await soloMath.setTminTmax(ONE.mul(1000),ONE.mul(887200));
      // can't go higher than the max
      await expect(await soloMath.computeTmax(ONE.mul(887100),ONE.div(200))).to.be.equal(ONE.mul(887272));
    });

  });


});
