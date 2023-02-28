# 1. Solo - The Liquidity Magnet

Solo is the first market maker to eliminate the zero-sum game between arbitrageurs and liquidity providers (LPs). 

# 2. Problem
Only sophisticated liquidity providers are able to afford the active management required to generate significant returns in legacy automated market makers (AMMs) such as Uniswap V3.

# 3. Solution
Solo uses shared concentrated liquidity and just-in-time rebalances to make it possible for everyone to earn with liquidity provision.

# 4. Vision
Every project will be able to get deep on-chain liquidity for the first time as Solo activates previously untapped sources of tokens with its simple, decentralized earn function.

# 5. How does it work?
Each Solo pool manages three positions: Flex, Concentrated, and Protected. These positions are managed to ensure liquidity provision and minimize the risk of impermanent loss for liquidity providers.

The allocation of tokens between these positions is reassessed after deposits and before trades.  In all cases, rebalancing is avoided if the number of blocks since the high volatility trigger is less than block delay (B < Bmin) in order to protect LPs from adversaries that may attempt to manipulate the price and then benefit from increased concentration at the manipulated price.
