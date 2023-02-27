deploy usdc and weth mock tokens
```
npx hardhat deploy --network mumbai --tags USDC
npx hardhat deploy --network mumbai --tags WETH
```
verify mocks
```
npx hardhat verify --network mumbai <USDC_ADDRESS> --contract contracts/test/USDC.sol:USDC
npx hardhat verify --network mumbai <WETH ADDRESS> --contract contracts/test/WETH9.sol:WETH9
```
To deploy uniswap system run

```
yarn deploy -pk [private-key] -j [json-rpc] -w9 [network token] -ncl [network token symbol] -o [owner address of uniswap contracts]
```

create a `.env` file from the `.env.sample`

To verify look at the `state.json`
run this command for every contract in there
```
npx hardhat verify --network [network name] [contract address]
```


Addresses

USDC
https://mumbai.polygonscan.com/token/0x4fA26462BDf5685571d9a421126755802c166b69

WETH
https://mumbai.polygonscan.com/token/0xb91bc1088d1f5c90f2dcc4b35bfeef4188bf32e6