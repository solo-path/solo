import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, tokenOwner} = await getNamedAccounts();

    await hre.run("verify:verify", {
        address: '0xb07B3D3b46a703F9Fcce00F4EE6c2FD0e50e27Dc',
        constructorArguments: ['0xA9081Ec57907e8dC69247Bb38E3e879a0C141abC']
        //libraries: { SoloMath: '0x360aC236F0d0faEe69E70c5A0E93AB90a00632Bb', SoloUV3Math: '0x1e9878d35fB4D69b95eB588874B51e3A94B9A359' }
    });

  
};
export default func;
func.tags = ['SoloFactoryVerify'];