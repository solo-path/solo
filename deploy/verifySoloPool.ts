import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {deployments, getNamedAccounts} = hre;
  const {deploy} = deployments;

  const {deployer, tokenOwner} = await getNamedAccounts();

    await hre.run("verify:verify", {
        address: '0x6A1806134E21eE05E097FB562CdB293b732841CC',
        constructorArguments: [ '0x1Efb4242106d1532143245AfD050d9e8C70473f5', //uniV3Factory
                                '0xCC57bcE47D2d624668fe1A388758fD5D91065d33', //tokenB
                                '0xB704143D415d6a3a9e851DA5e76B64a5D99d718b', //tokenA
                                false, //tokenAIsDeposit
                                '10000000000000000', //fee
                                'Solo DAI-WETH:50', //lpName
                                'DAI-WETH:50', //lpSymbol
      ]
    });

  
};
export default func;
func.tags = ['SoloPoolVerify'];