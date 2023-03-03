import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, tokenOwner} = await getNamedAccounts();

  const soloUV3MathLib = await deploy('SoloUV3Math', {
    from: deployer,
    log: true
  });

  const soloMathLib = await deploy('SoloMath', {
    from: deployer,
    libraries: { SoloUV3Math: soloUV3MathLib.address},
    log: true
  });

  const soloFactory = await deploy('SoloFactory', {
    from: deployer,
    args: ['0xA9081Ec57907e8dC69247Bb38E3e879a0C141abC'],  //solo instance of univ3Factory we deployed
    libraries: { SoloMath: soloMathLib.address, SoloUV3Math: soloUV3MathLib.address},
    log: true
  });

  
};
export default func;
func.tags = ['SoloFactory'];