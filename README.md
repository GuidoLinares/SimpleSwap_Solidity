# SimpleSwap_Solidity

Overview
SimpleSwap is a Solidity smart contract that provides core decentralized exchange (DEX) functionalities, similar to simplified versions of Uniswap. It enables users to add and remove liquidity to ERC-20 token pairs, as well as swap tokens between existing liquidity pools. The contract calculates exchange rates, applies fees, and manages liquidity provider (LP) tokens.

This project was developed as the final assignment for Module 3, aiming to replicate essential DEX mechanics without relying on external protocols.

Features
Liquidity Provision: Users can deposit a pair of ERC-20 tokens to create a new liquidity pool or add to an existing one. They receive LP tokens representing their share of the pool.
Liquidity Removal: Users can burn their LP tokens to retrieve their proportional share of the underlying ERC-20 tokens from the pool.
Token Swapping: Facilitates direct exchange of one ERC-20 token for another within an existing liquidity pool.
Price Discovery: Provides a function to query the current price of one token in terms of another based on the pool's reserves.
Amount Calculation: Includes a helper function to predict the output amount for a given token swap, accounting for fees.
Contract Details
Key Components
Pair Struct: Stores essential information for each liquidity pool, including tokenA, tokenB, their respective reserveA and reserveB amounts, totalSupply of LP tokens for that pair, and a mapping to track individual liquidityBalances.
getPairKey(address tokenA, address tokenB): A pure function that generates a unique bytes32 key for any token pair by consistently ordering the token addresses.
MINIMUM_LIQUIDITY: A constant to prevent "dust" liquidity and pool manipulation at creation.
FEE_RATE: Defines the swap fee (0.3%, represented as 997 for 997/1000).
Modifiers:
nonReentrant: Protects against reentrancy attacks using OpenZeppelin's ReentrancyGuard.
checkDeadline(uint256 deadline): Ensures transactions are executed before a specified timestamp.
validTokens(address tokenA, address tokenB): Verifies that token addresses are valid and not identical.
Core Functions
addLiquidity(LiquidityParams calldata params)

Allows users to add liquidity to a token pair.
If the pair doesn't exist, it initializes a new liquidity pool.
Calculates the amounts of tokenA and tokenB to be deposited, respecting desired and minimum amounts.
Transfers tokens from the user to the contract.
Mints LP tokens to the user based on their proportional contribution.
Emits a LiquidityAdded event.
removeLiquidity(RemoveParams calldata params)

Enables users to withdraw liquidity from a token pair.
Requires the user to burn their LP tokens.
Calculates and transfers the proportional amounts of tokenA and tokenB back to the user.
Emits a LiquidityRemoved event.
swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)

NOTE: This function in the provided code snippet requires a critical update to match the specified interface and functionality. The current implementation deviates significantly.
Intended Functionality (as per requirements): Allows users to swap a precise amountIn of one token for a minimum amountOutMin of another.
It should receive the input and output tokens via a path array (e.g., [tokenA_address, tokenB_address]).
Calculates the resulting amountOut based on current reserves and the FEE_RATE.
Transfers tokenIn from the user to the contract and tokenOut from the contract to the recipient.
Emits a TokensSwapped event.
ACTION REQUIRED: Please ensure this function's signature matches the requirement (address[] calldata path) and its internal logic correctly uses path[0] as tokenIn and path[1] as tokenOut for all calculations and transfers. The return type should also be uint256[] memory amounts.
getPrice(address tokenA, address tokenB) external view returns (uint256 price)

Retrieves the current price of tokenA in terms of tokenB from a specific liquidity pool.
Returns the price scaled by 1e18 for human readability (assuming 18 decimal tokens).
getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut)

A pure function to calculate the expected amount of output tokens received for a given amountIn, considering the pool's reserveIn, reserveOut, and the defined FEE_RATE. This uses a standard constant product (Uniswap V2-like) formula.
Helper Functions
_calculateLiquidityAmounts: Internal logic for determining token amounts during liquidity provision.
_calculateRemoveLiquidityAmounts: Internal logic for determining token amounts during liquidity removal.
_transferTokens: Internal function to handle reserve updates and token transfers during liquidity removal.
_getReserves: Internal helper to get ordered reserves based on tokenIn.
_updateReserves: Internal helper to update reserves after a swap.
quote: Calculates a quoted amount of one token needed for a desired amount of another, based on reserves.
sqrt: A utility function to calculate the integer square root, used for initial liquidity minting.
