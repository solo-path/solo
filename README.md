# 1. SOLO - The Liquidity Magnet

One token holder's trash is another's treasure.  SOLO is the first AMM to know the difference.  It works on behalf of LPs to grow their treasured tokens. 

# 2. Problem
Only sophisticated liquidity providers are able to afford the active management required to generate significant returns in legacy automated market makers (AMMs) such as Uniswap V3.

# 3. Solution
Solo uses shared concentrated liquidity and just-in-time rebalances to make it possible for everyone to earn with liquidity provision.

# 4. Vision
Every project will be able to get deep on-chain liquidity for the first time as Solo activates previously untapped sources of tokens with its simple, decentralized earn function.

# 5. How does it work?
Each Solo pool manages three positions: Flex, Concentrated, and Protected. These positions are managed to ensure liquidity provision and minimize the risk of selling too much of a depositor's treasured tokens.

The allocation of tokens between these positions is reassessed after deposits and before trades.  In all cases, rebalancing is avoided if the number of blocks since the high volatility trigger is less than block delay (B < Bmin) in order to protect LPs from adversaries that may attempt to manipulate the price and then benefit from increased concentration at the manipulated price.

For more details, check out the following resources:

- DEMO App: https://solo-trade.netlify.app/

- Brochure: https://drive.google.com/file/d/1HL9gDHm6MRdXPPmXFvPq7bwzHmSebBUS/view?usp=share_link

- Product Requirements + Math doc: https://docs.google.com/document/d/16Icw6yTT65-Q8X_OE53U2biJjpkqx0PADVESHXaGXgY/edit#

# 6. ETHDenver POC Details

## Live demo UI

https://solo-trade.netlify.app/

## Mumbai Deploy

### Tokens

WETH
https://mumbai.polygonscan.com/token/0xCC57bcE47D2d624668fe1A388758fD5D91065d33

DAI
https://mumbai.polygonscan.com/token/0xB704143D415d6a3a9e851DA5e76B64a5D99d718b

### Main Solo Contracts

SoloFactory - https://mumbai.polygonscan.com/address/0x7ABaf4f01976680D5F8eAa4bA9edFB3333E20eFc

DAI-WETH-50 Solo Pool - https://mumbai.polygonscan.com/address/0x2602ec23b476199e201257f04C260B4487D46Ab5

### Solo Uniswap V3

v3CoreFactoryAddress - https://mumbai.polygonscan.com/address/0x38Df002AC009f8AA3D9206b020940Bdf47607523

multicall2Address - https://mumbai.polygonscan.com/address/0x9e4b3bF5170dc50849e3e22B22cC731254A3E11F

proxyAdminAddress - https://mumbai.polygonscan.com/address/0xac4658BeDAc651B1296314Bd9e22508B41D40aD6

tickLensAddress - https://mumbai.polygonscan.com/address/0xac4658BeDAc651B1296314Bd9e22508B41D40aD6

nftDescriptorLibraryAddressV1_3_0 - https://mumbai.polygonscan.com/address/0xe33992400727707aa218F158e11f2c1de11d2270

nonfungibleTokenPositionDescriptorAddressV1_3_0 - https://mumbai.polygonscan.com/address/0x46a3F6cE4b53aAae5fd853883ae2F4571b74640E

descriptorProxyAddress - https://mumbai.polygonscan.com/address/0x73c607F8E96f83AD99a1f04Ac0Dc11131224dE54

nonfungibleTokenPositionManagerAddress - https://mumbai.polygonscan.com/address/0x00875C58577b57113Ea14Dc8121500Eb29b09E6b

v3MigratorAddress - https://mumbai.polygonscan.com/address/0x5278452E356449b6a624F57ec1a5C74F507617C1

v3StakerAddress - https://mumbai.polygonscan.com/address/0x8b0C8c8C9af2fAE24F3caa2bAb5000A240786A4b

quoterV2Address - https://mumbai.polygonscan.com/address/0x56f6860B18F9496f040420ba36dF8acE84E5458E

swapRouter02 - https://mumbai.polygonscan.com/address/0xE8dFB1b10ae5FC25B6726862167b24d8c5EFdB28

# 7. Why did we choose Polygon?

Polygon is a Layer 2 scaling solution for Ethereum, which is a blockchain that allows developers to build decentralized applications (dApps) and smart contracts. Polygon offers a high-performance, low-cost, and secure infrastructure that enables developers to deploy their applications and services quickly and easily. One of the most significant advantages of Polygon is its ability to support various decentralized finance (DeFi) applications, including Automated Market Makers (AMMs).

Automated Market Makers (AMMs) are a type of decentralized exchange (DEX) that uses smart contracts to automatically set prices for assets. AMMs have become increasingly popular in the DeFi space due to their ability to provide liquidity and trade pairs without the need for centralized intermediaries. Polygon is an excellent place to deploy a novel AMM for several reasons, including:

High Performance and Low Transaction Fees:

Polygon is designed to offer high performance and low transaction fees, making it an ideal platform for AMMs. Compared to the Ethereum network, Polygon's transaction fees are significantly lower, which means that developers can deploy their AMMs without worrying about high gas fees. Additionally, Polygon's network can handle a much higher volume of transactions per second, which allows AMMs to execute trades quickly and efficiently.

Interoperability and Support for Smart Contracts:

Polygon is highly interoperable with Ethereum, which means we were able to easily deploy our Ethereum-based AMM on Polygon. Polygon supports a range of programming languages, including Solidity, which allowed us to code Solo AMM using our preferred language.

Large and Growing User Base:

Polygon has a large and growing user base, with many users seeking to use DeFi applications on its network due to its high-performance capabilities and low transaction fees. Deploying a novel AMM on Polygon will enable us to tap into this growing user base and attract more users to their platform. Additionally, Polygon has a thriving community of developers and enthusiasts, which can provide support and feedback to developers as they deploy their AMMs.

Conclusion:

Polygon is a great place to deploy a novel AMM due to its high-performance capabilities, low transaction fees, interoperability, large and growing user base, and support for smart contracts. By deploying Solo AMM on Polygon, we will be able to reach a broader range of users and tap into a thriving DeFi ecosystem.
