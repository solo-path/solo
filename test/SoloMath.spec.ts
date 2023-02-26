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

  describe('liquidity amounts for flex and concentrated positions', () => {
    it('moreYthanX', async () => {
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(1000),
        ZERO, ZERO);

      // sqrtP_1:  707106781187000000 // of 0.5
      // sqrtP_2: 1224744871390000000 // of 1.5

      let res = await soloMath.moreYthanX(BigNumber.from("707106781187000000"));
      await expect(res).to.eq(true);
      res = await soloMath.moreYthanX(BigNumber.from("1224744871390000000"));
      await expect(res).to.eq(false);
      res = await soloMath.moreYthanX(BigNumber.from("1000000000000000000")); // 1
      await expect(res).to.eq(false);

    });

    it('computeFxFy', async () => {
      // price: 100, pMin: 50, pMax: 150, Fpct = 90%
      // sqrtPMin:  7071067811870000000
      // sqrtPMax: 12247448713900000000
      // x: 1000, y: 2000
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(2000),
        BigNumber.from("7071067811870000000"), BigNumber.from("12247448713900000000"));

      let res = await soloMath.computeFxFy(ONE.mul(10),ONE.mul(90).div(100));
      //console.log(res[0].toString());
      //console.log(res[1].toString());
      await expect(res[0]).to.be.equal(BigNumber.from("11277357518443363748"));
      await expect(res[1]).to.be.equal(ONE.mul(1800));

      // price: 1, pMin: 0.5, pMax: 1.5, Fpct = 100%
      // sqrtPMin:  707106781187000000
      // sqrtPMax: 1224744871390000000
      // x: 1000, y: 1000
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(1000),
        BigNumber.from("707106781187000000"), BigNumber.from("1224744871390000000"));

      res = await soloMath.computeFxFy(ONE,ONE);
      //console.log(res[0].toString());
      //console.log(res[1].toString());
      await expect(res[0]).to.be.equal(BigNumber.from("626519862135742431293"));
      await expect(res[1]).to.be.equal(ONE.mul(1000));

      // price: 1, pMin: 0.5, pMax: 1.5, Fpct = 100%
      // sqrtPMin:  707106781187000000
      // sqrtPMax: 1224744871390000000
      // x: 1000, y: 2000
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(2000),
        BigNumber.from("707106781187000000"), BigNumber.from("1224744871390000000"));

      res = await soloMath.computeFxFy(ONE,ONE);
      //console.log(res[0].toString());
      //console.log(res[1].toString());
      await expect(res[0]).to.be.equal(ONE.mul(1000));
      await expect(res[1]).to.be.equal(BigNumber.from("1596118591661406868110"));
    });

    it('computeCxCy', async () => {
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(2000),
        ZERO, ZERO);

      let res = await soloMath.computeCxCy(ONE.mul(1000),ONE.mul(2000));
      await expect(res[0]).to.be.equal(ZERO);
      await expect(res[1]).to.be.equal(ZERO);

      // TODO check for negative Cx/Cy doesn't work
      //const msg1 = "negative Cx/Cy";
      // negavice Cx/Cy
      //await expect(soloMath.computeCxCy(ONE.mul(1001),ONE.mul(2000))).to.be.revertedWith(msg1);
      //await expect(soloMath.computeCxCy(ONE.mul(1000),ONE.mul(2001))).to.be.revertedWith(msg1);

      res = await soloMath.computeCxCy(ONE.mul(600),ONE.mul(1000));
      await expect(res[0]).to.be.equal(ONE.mul(400));
      await expect(res[1]).to.be.equal(ONE.mul(1000));

    });

  });

  describe('pre-trade assessment', () => {
    it('preTradeAssessment', async () => {
      // price: 1, Fpct = 90%, Rptc = 10%
      // x: 1000, y: 1000
      // Fx: 500, Fy: 500
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(1000),
        ZERO, ZERO);

      let res = await soloMath.preTradeAssessment(
        ONE,ONE.mul(500),ONE.mul(500),ONE.mul(90).div(100),ONE.mul(10).div(100));
      await expect(res).to.eq(true);

      // price: 1, Fpct = 90%, Rptc = 10%
      // x: 1000, y: 1000
      // Fx: 900, Fy: 900
      res = await soloMath.preTradeAssessment(
        ONE,ONE.mul(900),ONE.mul(900),ONE.mul(90).div(100),ONE.mul(10).div(100));
      await expect(res).to.eq(false);

      // price: 1, Fpct = 90%, Rptc = 10%
      // x: 1000, y: 1100
      // Fx: 900, Fy: 900
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(1100),
        ZERO, ZERO);
      res = await soloMath.preTradeAssessment(
        ONE,ONE.mul(900),ONE.mul(900),ONE.mul(90).div(100),ONE.mul(10).div(100));
      await expect(res).to.eq(false);

      // price: 1, Fpct = 90%, Rptc = 10%
      // x: 1000, y: 1100
      // Fx: 800, Fy: 900
      res = await soloMath.preTradeAssessment(
        ONE,ONE.mul(800),ONE.mul(900),ONE.mul(90).div(100),ONE.mul(10).div(100));
      await expect(res).to.eq(true);

    });
  });

  describe('steps', () => {
    it('step1', async () => {
      // fee = 1%

      const msg1 = "rax and ray cannot both be > 0";
      const msg2 = "rax and ray cannot both be 0";

      // TODO find out how to catch these exceptions
      
      //await expect(soloMath.step1(ONE.mul(1000),ONE.mul(1000),ONE.div(100))).to.be.revertedWith(msg1);
      //await expect(soloMath.step1(ONE.mul(0),ONE.mul(0),ONE.div(100))).to.be.revertedWith(msg2);

      let res = await soloMath.step1(ONE.mul(1000),ONE.mul(0),ONE.div(100));
      await expect(res[0]).to.eq(ONE.mul(990));
      res = await soloMath.step1(ONE.mul(0),ONE.mul(1000),ONE.div(100));
      await expect(res[1]).to.eq(ONE.mul(990));

    });
  
    it('step3a', async () => {
      await soloMath.setState_pf(ONE);

      let res = await soloMath.step3a(true,ONE.div(100));
      await expect(res[0]).to.eq(ONE.mul(99).div(100));
      await expect(res[1]).to.eq(0);

      res = await soloMath.step3a(false,ONE.div(100));
      await expect(res[0]).to.eq(0);
      await expect(res[1]).to.eq(ONE.mul(101).div(100));
    });

    it('step3b', async () => {
      // price: 1, pMin: 0.5, pMax: 1.5, Fpct = 100%
      // sqrtPMin:  707106781187000000
      // sqrtPMax: 1224744871390000000
      await soloMath.setState_x_y_sqrtPMin_sqrtPMax(ONE.mul(1000),ONE.mul(1000),
        BigNumber.from("707106781187000000"), BigNumber.from("1224744871390000000"));

      let res = await soloMath.step3b(true,BigNumber.from("1000000000000000000"),
        ONE.mul(1000),ONE.mul(1000),BigNumber.from("990000000000000000"),ZERO);
      await expect(res[0]).to.eq(ZERO);
      await expect(res[1]).to.eq(BigNumber.from("27315910072687821523")); // 27

      res = await soloMath.step3b(true,BigNumber.from("1000000000000000000"),
        ONE.mul(1000),ONE.mul(1000),BigNumber.from("1010000000000000000"),ZERO);
      await expect(res[0]).to.eq(ZERO);
      await expect(res[1]).to.eq(ZERO);

      res = await soloMath.step3b(false,BigNumber.from("1000000000000000000"),
        ONE.mul(1000),ONE.mul(1000),ZERO,BigNumber.from("1010000000000000000"));
      await expect(res[0]).to.eq(BigNumber.from("16944092492559240925")); // 16
      await expect(res[1]).to.eq(ZERO);

      res = await soloMath.step3b(false,BigNumber.from("1000000000000000000"),
        ONE.mul(1000),ONE.mul(1000),ZERO,BigNumber.from("990000000000000000"));
      await expect(res[0]).to.eq(ZERO);
      await expect(res[1]).to.eq(ZERO);
    });

    it('step3c', async () => {
      let res = await soloMath.step3c(true,
        ZERO,ONE,
        ONE.mul(9),ZERO,
        ONE,ONE.mul(2));
      await expect(res[0]).to.eq(ONE.mul(9));
      await expect(res[1]).to.eq(0);
      await expect(res[2]).to.eq(true);

      res = await soloMath.step3c(true,
        ZERO,ONE.mul(10),
        ONE,ZERO,
        ONE,ONE.mul(2));
      await expect(res[2]).to.eq(false);

      res = await soloMath.step3c(false,
        ONE,ZERO,
        ZERO,ONE.mul(9),
        ONE.mul(2),ONE);
      await expect(res[0]).to.eq(0);
      await expect(res[1]).to.eq(ONE.mul(9));
      await expect(res[2]).to.eq(true);

      res = await soloMath.step3c(false,
        ONE.mul(10),ZERO,
        ZERO,ONE,
        ONE.mul(2),ONE);
      await expect(res[2]).to.eq(false);

    });
  
  });


});
