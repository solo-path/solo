import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, tokenOwner} = await getNamedAccounts();

    await hre.run("verify:verify", {
        address: '0xeaCFe13572828319D5ae19Df312f78F6074A425d',
        constructorArguments: ['0x1Efb4242106d1532143245AfD050d9e8C70473f5']
        //libraries: { SoloMath: '0x360aC236F0d0faEe69E70c5A0E93AB90a00632Bb', SoloUV3Math: '0x1e9878d35fB4D69b95eB588874B51e3A94B9A359' }
    });

  
};
export default func;
func.tags = ['SoloFactoryVerify'];