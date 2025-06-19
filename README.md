# SimpleSwap Smart Contract

## Overview

`SimpleSwap` is a Solidity smart contract that provides core decentralized exchange (DEX) functionalities, similar to simplified versions of Uniswap. It enables users to **add and remove liquidity** to ERC-20 token pairs, as well as **swap tokens** between existing liquidity pools. The contract calculates exchange rates, applies fees, and manages liquidity provider (LP) tokens.

This project was developed as the final assignment for Module 3, aiming to replicate essential DEX mechanics without relying on external protocols.

## Features

* **Liquidity Provision:** Users can deposit a pair of ERC-20 tokens to create a new liquidity pool or add to an existing one. They receive LP tokens representing their share of the pool.
* **Liquidity Removal:** Users can burn their LP tokens to retrieve their proportional share of the underlying ERC-20 tokens from the pool.
* **Token Swapping:** Facilitates direct exchange of one ERC-20 token for another within an existing liquidity pool.
* **Price Discovery:** Provides a function to query the current price of one token in terms of another based on the pool's reserves.
* **Amount Calculation:** Includes a helper function to predict the output amount for a given token swap, accounting for fees.

## Contract Details

### Key Components

* **`Pair` Struct:** Stores essential information for each liquidity pool, including `tokenA`, `tokenB`, their respective `reserveA` and `reserveB` amounts, `totalSupply` of LP tokens for that pair, and a `mapping` to track individual `liquidityBalances`.
* **`getPairKey(address tokenA, address tokenB)`:** A pure function that generates a unique `bytes32` key for any token pair by consistently ordering the token addresses.
* **`MINIMUM_LIQUIDITY`:** A constant to prevent "dust" liquidity and pool manipulation at creation.
* **`FEE_RATE`:** Defines the swap fee (0.3%, represented as `997` for `997/1000`).
* **Modifiers:**
    * `nonReentrant`: Protects against reentrancy attacks using OpenZeppelin's `ReentrancyGuard`.
    * `checkDeadline(uint256 deadline)`: Ensures transactions are executed before a specified timestamp.
    * `validTokens(address tokenA, address tokenB)`: Verifies that token addresses are valid and not identical.

### Core Functions

1.  **`addLiquidity(LiquidityParams calldata params)`**
    * Allows users to add liquidity to a token pair.
    * If the pair doesn't exist, it initializes a new liquidity pool.
    * Calculates the amounts of `tokenA` and `tokenB` to be deposited, respecting desired and minimum amounts.
    * Transfers tokens from the user to the contract.
    * Mints LP tokens to the user based on their proportional contribution.
    * Emits a `LiquidityAdded` event.

2.  **`removeLiquidity(RemoveParams calldata params)`**
    * Enables users to withdraw liquidity from a token pair.
    * Requires the user to burn their LP tokens.
    * Calculates and transfers the proportional amounts of `tokenA` and `tokenB` back to the user.
    * Emits a `LiquidityRemoved` event.

3.  **`swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)`**
    * **IMPORTANT: The provided `swapExactTokensForTokens` function in the original code snippet needs to be updated to match the required interface and correct its internal logic.**
    * **Intended Functionality (as per project requirements):** Allows users to swap a precise `amountIn` of one token for a minimum `amountOutMin` of another.
    * It should receive the input and output tokens via a `path` array (e.g., `[tokenA_address, tokenB_address]`).
    * Calculates the resulting `amountOut` based on current reserves and the `FEE_RATE`.
    * Transfers `tokenIn` from the user to the contract and `tokenOut` from the contract to the recipient.
    * Emits a `TokensSwapped` event.
    * **Before deployment, ensure this function's signature matches `address[] calldata path` for the `path` parameter and returns `uint256[] memory amounts`. Additionally, ensure internal logic correctly uses `path[0]` as `tokenIn` and `path[1]` as `tokenOut` for all calculations and transfers.**

4.  **`getPrice(address tokenA, address tokenB) external view returns (uint256 price)`**
    * Retrieves the current price of `tokenA` in terms of `tokenB` from a specific liquidity pool.
    * Returns the price scaled by `1e18` for human readability (assuming 18 decimal tokens).

5.  **`getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut)`**
    * A pure function to calculate the expected amount of output tokens received for a given `amountIn`, considering the pool's `reserveIn`, `reserveOut`, and the defined `FEE_RATE`. This uses a standard constant product (Uniswap V2-like) formula.

### Helper Functions

* `_calculateLiquidityAmounts`: Internal logic for determining token amounts during liquidity provision.
* `_calculateRemoveLiquidityAmounts`: Internal logic for determining token amounts during liquidity removal.
* `_transferTokens`: Internal function to handle reserve updates and token transfers during liquidity removal.
* `_getReserves`: Internal helper to get ordered reserves based on `tokenIn`.
* `_updateReserves`: Internal helper to update reserves after a swap.
* `quote`: Calculates a quoted amount of one token needed for a desired amount of another, based on reserves.
* `sqrt`: A utility function to calculate the integer square root, used for initial liquidity minting.

## Development Setup

To compile and deploy this contract, you'll need the following:

1.  **Solidity Compiler:** Version `0.8.19` or higher.
2.  **Hardhat or Foundry:** For local development, testing, and deployment.
3.  **OpenZeppelin Contracts:** The project imports `ReentrancyGuard.sol` and `IERC20.sol` from OpenZeppelin. Ensure these are installed in your project:
    ```bash
    npm install @openzeppelin/contracts
    # or
    forge install OpenZeppelin/openzeppelin-contracts
    ```

### Compilation

You can compile the contract using `solc` directly or through your chosen development framework:

```bash
# Example with Hardhat
npx hardhat compile

# Example with Foundry
forge build


// Assuming 'MyTokenA' and 'MyTokenB' are deployed ERC20 tokens
// and SimpleSwap is deployed as 'simpleSwapAddress'

// 1. Approve SimpleSwap to spend your tokens
IERC20(tokenA_address).approve(simpleSwapAddress, amountA_to_add);
IERC20(tokenB_address).approve(simpleSwapAddress, amountB_to_add);

// 2. Add Liquidity
SimpleSwap(simpleSwapAddress).addLiquidity({
    tokenA: tokenA_address,
    tokenB: tokenB_address,
    amountADesired: 1e18, // 1 token A
    amountBDesired: 1e18, // 1 token B
    amountAMin: 0.9e18,   // min 0.9 token A
    amountBMin: 0.9e18,   // min 0.9 token B
    to: msg.sender,
    deadline: block.timestamp + 300 // 5 minutes from now
});

// 3. Swap Tokens (after correcting the swapExactTokensForTokens function as advised)
// First, ensure your contract's swapExactTokensForTokens matches the required interface:
// function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
IERC20(tokenA_address).approve(simpleSwapAddress, amount_to_swap); // Approve input token

SimpleSwap(simpleSwapAddress).swapExactTokensForTokens(
    amount_to_swap, // amountIn
    amount_out_min, // amountOutMin
    [tokenA_address, tokenB_address], // path: [inputToken, outputToken]
    msg.sender,     // to: recipient of the output tokens
    block.timestamp + 300 // deadline
);

// 4. Get Price
uint256 price = SimpleSwap(simpleSwapAddress).getPrice(tokenA_address, tokenB_address);
// For instance, if price = 1e18, then 1 TokenA = 1 TokenB
// if price = 2e18, then 1 TokenA = 2 TokenB
console.log("Price of TokenA in terms of TokenB:", price);


Audit Considerations & Security
Reentrancy Protection: The nonReentrant modifier is used on critical functions to prevent reentrancy attacks.
Slippage Control: amountAMin, amountBMin, and amountOutMin parameters help users protect against unfavorable price movements during liquidity provision and swaps.
Transaction Deadlines: The deadline parameter prevents transactions from being executed long after they were intended.
Price Manipulation: Like all AMMs, this contract is susceptible to sandwich attacks and impermanent loss. Users should be aware of these risks.
Gas Optimization: While functional, further gas optimizations could be explored for a production environment.
