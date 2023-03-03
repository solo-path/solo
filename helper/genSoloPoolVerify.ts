import { ethers, Wallet, BigNumber } from 'ethers';
import { JsonRpcProvider } from '@ethersproject/providers'
import SoloFactory from '../artifacts/contracts/solo/SoloFactory.sol/SoloFactory.json';
import Solo from '../artifacts/contracts/solo/Solo.sol/Solo.json';


require('dotenv').config();

const jsonRpcProviderURL: string = process.env.JSON_RPC as string | 'http://localhost:8545'


async function main() {
    const mnemonicPhrase: string = process.env.MENMONIC as string || 'oven horror banner plate siren radio doctor round sting nest frequent apart';

    const wallet = ethers.Wallet.fromMnemonic(mnemonicPhrase,`m/44'/60'/0'/0/4`);

    const signer = new Wallet(wallet.privateKey, new JsonRpcProvider({ url: jsonRpcProviderURL }))

    const soloPool = new ethers.Contract('0x6A1806134E21eE05E097FB562CdB293b732841CC',Solo.abi, signer);

    const tokenA = await soloPool.token0();
    const tokenB = await soloPool.token1();
    const isDepoist = await soloPool.token0IsDeposit();
    const fee = await soloPool.fee();
    const lpName = await soloPool.name();
    const lpSymbol = await soloPool.symbol();

    console.log(tokenA);
    console.log(tokenB);
    console.log(isDepoist);
    console.log(fee.toString());
    console.log(lpName);
    console.log(lpSymbol);
    

}

main();