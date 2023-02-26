# 1. Solo

Solo is a protocol that provides deep and efficient liquidity for trading tokens, while eliminating the zero-sum game between arbitrageurs and liquidity providers (LPs) that is common in traditional AMMs.

In order to accomplish this, Solo uses a combination of shared concentrated liquidity and refined strategies that are embedded into the AMM itself. This allows liquidity providers (LPs) to select pools that align with their risk tolerance, and liquidity ranges are adjusted before executing trades, minimizing the risk of selling tokens beneath market value. The result is a streamlined and efficient liquidity provision process that benefits both traders and LPs.

Solo also addresses some of the issues that are common with traditional AMMs. For example, it mitigates toxic arbitrage and "impermanent loss" by introducing refined strategies into the AMM itself, which eliminates the need for constant updates from LPs. This makes the process of providing liquidity more efficient and streamlined, while also minimizing the risk of selling tokens beneath market value.

One of the unique features of Solo is its simple, decentralized "earn" function. With single token deposit, anyone can earn money by providing liquidity without needing to worry about the complexities of traditional AMMs. This makes liquidity provision attractive to a wide range of token holders, including community members, project backers, team members, advisors, crypto hedge funds, and professional trading firms.

Solo is a non-custodial protocol, meaning that it does not hold onto users' tokens or have the ability to control their funds. It is also censorship-resistant, ensuring that users have the freedom to use the protocol without interference from external parties. The protocol has fully automated and algorithmic operations, ensuring accurate and efficient execution of liquidity provision strategies. It is also 100% governance-free, meaning there is no central authority or group of individuals with decision-making power over the protocol.

Overall, Solo is a great option for anyone looking to trade tokens and make some money without all the hassle. Its fully automated and algorithmic operation, combined with single token deposit, make it easy for anyone to earn with their tokens. 

# 2. Solo's Users
Solo is a platform that lets you trade tokens and earn money by providing liquidity. There are four types of users:
- LPs (liquidity providers) provide liquidity while keeping their chosen level of long exposure to a single deposit token
- Arbitrageurs buy and sell assets to profit from price differences in different markets
- Frontend operators host user interfaces and make it easy to use Solo
- Token communities incentivize the use of their own token in Solo
All four types of users are important for Solo to work well.

# 3. Shared Concentrated Liquidity with Just-in-Time Rebalances
Solo uses shared concentrated liquidity and just-in-time rebalances to create deep and efficient liquidity for trading tokens.

In Solo, every pool only accepts deposits of a single ERC20 token. The deposit token is the token that is supplied to Solo, and the quote token is the token that is specified as the other side of the trading pair. This is different from other AMMs, where recipients of a given pool token begin with varying financial exposure to different tokens.

To lessen the risk of losing the desired long exposure, Solo enables protected deposit tokens. These tokens are not used in liquidity provision and will remain in the possession of the LPs, even if an infinite number of the quote tokens are swapped into the pool for deposit tokens. In future versions of Solo, these protected tokens may be used in perpetual trading.

Solo also uses a flex swap approach to mitigate toxic arbitrage, and a dynamic concentration percentage to maximize capital efficiency.

## 4. Implementing a Solo Demo
For the demo, we implemented the following equations in a wrapper around the existing Uniswap V3 core contracts.  This will enable trades to execute changes to the pool's shared liquidity position according to the following equations.

These symbols be used in this discussion:
- B (Number of blocks since the last concentration reset)
- Bmin (Minimum number of blocks since the last reset)
- Cpct (Concentration Percentage. Used to determine how many tokens from the Concentrated position could be utilized in a trade)
- Cx (Amount of first (deposit) token in the Concentrated position)
- Cy (Amount of second (quote) token in the Concentrated position)
- Dpct (Percentage of deposit tokens to be allocated to the Protected position)
- Fee (Pool’s Trading Fee)
- Fpct (Maximum percent of x and y to be placed into the Flex liquidity position)
- Fx (Amount of first (deposit) token in the Flex liquidity position)
- Fy (Amount of second (quote) token in the Flex liquidity position)
- P (Price)
- Pmax (Square root of the upper range price in the Flex position)
- Pmin (Square root of the lower range price in the Flex position)
- Px (Amount of first (deposit) token in the Protected position)
- Rpct (Rebalance threshold (percentage). Used to determine the maximum size at which the Flex position could grow before triggering a rebalance)
- S (Speed parameter for the concentration increase after a reset)
- Tc (Current price tick)
- Tmax (Upper range price tick in the Flex position)
- Tmin (Lower range price tick in the Flex position)
- Tpct (Trading Range threshold (percentage). Used to determine how many ticks the price can move within Flex posistion before causing expansion of the flex position)
- X (The first (deposit) token)
- x (Amount of first (deposit) token in Solo’s liquidity positions. This value does not include X tokens placed into the Protected position)
- Y (The second (quote) token)
- y	(Amount of second (quote) token in Solo’s liquidity positions)

4.1 Solo’s Liquidity Positions
Each Solo pool manages three positions: Flex, Concentrated, and Protected. These positions are managed to ensure liquidity provision and minimize the risk of impermanent loss for liquidity providers.

4.1.1 Flex Position
Active, contains both quote and deposit tokens.
Makes a market at every price point within its boundaries
Expands when the price approaches its boundaries
Protects against manipulation
4.1.2 Concentrated Position
Tokens available for trading at a price determined by the end of the most recent flex swap
Not subject to impermanent loss in any single trade
Trades that cause a volatility trigger will not have access to tokens in the concentrated position
Reappears slowly over many blocks after a volatility trigger
4.1.3 Protected Position
Tokens protected from impermanent loss by being kept outside of liquidity provision.

The sum of these positions is equal to the total number of tokens in the pool.

4.2 Flex Position
The Flex position is constrained between the Tmin and Tmax ticks. When Tc approaches either boundary, that is

min(Tc-Tmin,Tmax-Tc)<Tmax - Tmin2Tpct100	(4.1)

and a trade is made to move the price even closer (or beyond) that boundary, the boundary is shifted in such a way that Tc ends up in the middle of the flex position.

For example, if Tmin boundary is moved, 

new Tmin = max(-887272,2Tc-Tmax)	(4.2)

This happens prior to the execution of the trade and both the flex and concentrated positions are also rebalanced. The trade that shifts the boundary must not occur in the same block as the trade that brought the price close to the boundary.

4.3 Determining Liquidity Amount for Each Position
The token allocation in each position is updated during periodic rebalancing. These rebalances occur during deposit and withdrawal transactions, as well as certain trades (as detailed in Section 4.4). The calculation of token amounts in each position during a rebalance follows these steps:

4.3.1 Flex Position Calculations
The following calculations use this equation.

FxPPmaxPmax-P=Fy1P-Pmin	(4.3)

(4.4 and 4.5) calculate Fx, number of X tokens in the Flex position.

If y>xP then Fx =xFpct100	(4.4)
If yxP then Fx=FyPmax-PPPmax(P-Pmin)	(4.5)

(4.6 and 4.7) calculate Fy, number of Y tokens in the Flex position.

If y>xP then Fy=FxPPmax(P-Pmin)Pmax-P	(4.6)
If yxP then Fy =yFpct100	(4.7)	

4.3.2 Concentrated Position Calculations
(4.8 and 4.9) calculate the number of tokens that are in the concentrated position, eligible for concentration.
	Cx=x-Fx	(4.8)
	Cy=y-Fy	(4.9)

4.3.3 Protected Position
The Protected position is mostly made up of deposit tokens. These tokens are allocated to the Protected position when users deposit funds into the pool, with the quantity determined by the Deposit Percentage (Dpct) setting. When the pool is reseeded, the Protected Position also receives both quote and deposit tokens in addition to the existing tokens.Tokens are removed from this position when users withdraw from the pool in proportion to their number of LP tokens.

4.4 Rebalancing Between Flex and Concentrated Positions
The allocation of tokens between the Flex position and the Concentrated position is reassessed after deposits and before trades.  In all cases, rebalancing is avoided if the number of blocks since the high volatility trigger is less than block delay (B < Bmin) in order to protect LPs from adversaries that may attempt to manipulate the price and then benefit from increased concentration at the manipulated price.

4.4.1 Post-Deposit Assessment
Rebalancing triggered by a deposit is carried out immediately after the completion of the deposit.

4.4.2 Pre-Trade Deposit Assessment
A rebalance is executed prior to a trade if either (4.10) or (4.11) is TRUE.

AND ((y>xP), (Fx(1+Rpct100)<x Fpct100))                (4.10)
AND ((yxP), (Fy(1+Rpct100)< yFpct100))                (4.11)

The trader is paying gas cost to execute the rebalance.  This expense is offset because a pre-trade rebalance also increases liquidity depth in the flex position.

4.5 Dynamic Concentration
Before executing a trade, Solo evaluates the potential impact it may have on the price within the pool and determines whether to utilize concentrated liquidity from the Concentrated position and, if so, how much. These decisions are based on the trade's expected effect on the price and previous volatility within the pool. 

In order to illustrate how dynamic concentration works, let’s review steps Solo performs when a new trade order is received.

Step 0
The current state of the pool is illustrated in (figure 1).

		
(figure 1)

A new exact input order is received to swap a certain number of X tokens (RAx) for Y tokens or to swap a certain number of Y tokens (RAy) for X tokens.

Step 1
Calculate the Ax or Ay, the specific quantity of either X or Y tokens used in the swap, by subtracting the fee.
	If X for Y then Ax=RAx(1-Fee) 	(4.12)
	If Y for X then Ay=RAy(1-Fee)	(4.13)

Step 2
Evaluate whether either of the Flex position boundaries needs to be adjusted, and update Pmin or Pmax accordingly, if required. See section 4.2

Step 3
Calculate the maximum price movement that a trade can cause without losing eligibility to use funds from the Concentrated position.

It's important to note that multiple price movements can occur within a single block. To account for the cumulative effect of these movements, Solo maintains a record of the spot price before the first trade in the block (Pf).

(figure 2)

If X tokens are swapped for Y tokens, we calculate the lower price movement threshold (Pa)
	Pa=Pf(1-Fee)	(4.14)
If Y tokens are swapped for X tokens, we calculate the upper price movement threshold (Pb)
	Pb=Pf(1+Fee)	(4.15)

Once we know the price movement threshold, we can calculate the maximum trade size that can be executed against the Flex position without exceeding the threshold.

If X tokens are swapped for Y tokens
                  If Pa >=P, then Ymax=0                                                (4.16)
                  If Pa <P, then Ymax=FxPPmax(P-Pa)Pmax-P                 (4.17)
If Y tokens are swapped for X tokens
                  If Pb <=P, then Xmax=0                                                (4.18)
                  If Pb >P, then Xmax=FyPb-PPPb(P-Pmin)                 (4.19)

By comparing the maximum trade size with the actual trade size, we can determine whether the Concentrated position can be used.

If X tokens are swapped for Y tokens and 			YmaxPa <Ax 	(4.20)
or Y tokens are swapped for X tokens and 			XmaxPb <Ay	(4.21)
then the trade is executed against the Flex position and the Concentrated position is reset (see section 4.3.1)

Otherwise, execution proceeds to Step 4  

Step 4
Determine the amount of tokens that could be sold from the Concentrated position.

First, calculate the concentration percentage: 
	Concentration Percentage (%) = Cpct=1-e(-(B-Bmin)/S)	(4.22)

For example, using the values of Bmin=10 and S=1500, Table 1 shows the concentration percentage calculation for various values of B. As the number of blocks increases, the concentration percentage gradually increases, allowing for a balance between protecting LPs and maximizing trading volume and fees.


Table 1 - Example Calculation of Concentration Percentage

Next, apply concentration percentage (C%) to Cx and Cy (total amounts of tokens inside the Concentrated Position) to determine the number of tokens (ACx and ACy) that can be utilized in the trade.

	ACx=CxCpct	(4.23)
	ACy=CyCpct	(4.24)

Step 5
Determine amounts of tokens to be traded against the Flex position (FAx and FAy) and against the Concentrated position (CAx and CAy).

If X tokens are swapped for Y tokens:

First determine the maximum amount of Y tokens that the simulated trade from Step 3 would have acquired (Fy)
	Fy=AxP	(4.25)
 
Use the ratio between ACy and Fy to determine how many X tokens (FAx) from the supplied amount to be used against the Flex position during the trade
	FAx=AxFyFy+ACy 	(4.26)

Determine how many X tokens (CAx) from the supplied amount to be used against the Concentrated position during the trade
	CAx=Ax-FAx	(4.27)

If Y tokens are swapped for X tokens:

First determine the maximum amount of X tokens that the simulated trade from Step 3 would have acquired (Fx)
	Fx=Ay  P 	(4.28)

Use the ratio between ACx and Fx to determine how many Y tokens (FAy) from the supplied amount to be used against the Flex position during the trade
	FAy=AyFxFx+ACx 	(4.29)

Determine how many Y tokens (CAy) from the supplied amount to be used against the Concentrated position during the trade
	CAy=Ay-FAy	(4.30)

Step 6
Execute swap control flow for the partial trade against the Flex position using FAx or FAy amount from Step 5.

When the swap flow is completed the pool will acquire a new spot price (SP).
The flow will also produce the exact amount of output tokens (FOx or FOy) from the partial trade.

Step 7
Execute the remainder of the trade against the Concentrated position using newly established SP. Calculate the exact amount of output token (Ox or Oy) to send to the user who submitted the trade.

If X tokens are swapped for Y tokens:
	COy=CAxSP	(4.31)
	Oy=min(FOy+COy, ACy)	(4.32)

If Y tokens are swapped for X tokens:
	COx=CAySP	(4.33)
	Ox=min(FOx+COx, ACx)	(4.34)

