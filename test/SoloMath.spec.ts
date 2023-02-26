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

});
