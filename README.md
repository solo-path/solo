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

DEMO App: https://solo-trade.netlify.app/
Brochure: https://drive.google.com/file/d/1HL9gDHm6MRdXPPmXFvPq7bwzHmSebBUS/view?usp=share_link
Product Requirements + Math doc: https://docs.google.com/document/d/16Icw6yTT65-Q8X_OE53U2biJjpkqx0PADVESHXaGXgY/edit#

