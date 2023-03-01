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
    args: ['0x1Efb4242106d1532143245AfD050d9e8C70473f5'],  //solo instance of univ3Factory we deployed
    libraries: { SoloMath: soloMathLib.address, SoloUV3Math: soloUV3MathLib.address},
    log: true
  });

  
};
export default func;
func.tags = ['SoloFactory'];