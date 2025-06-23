# SimpleSwap Smart Contract

---

## 🎯 Objective

This repository contains the `SimpleSwap` smart contract, an Automated Market Maker (AMM) designed to replicate core functionalities similar to Uniswap V2. The goal is to allow users to add and remove liquidity, swap tokens, get price information, and calculate output amounts, all without relying on the Uniswap protocol itself.

---

## 📢 Requirements & Features

The `SimpleSwap` contract implements the following key functionalities:

### 1. Add Liquidity (`addLiquidity`)

* **Description:** Allows users to add liquidity to an ERC-20 token pair in a liquidity pool.
* **Interface:**
    ```solidity
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
    ```
* **Tasks:**
    * Transfers input tokens from the user to the contract.
    * Calculates and allocates liquidity based on current reserves.
    * Mints and issues liquidity tokens to the user.
* **Parameters:**
    * `tokenA`, `tokenB`: Addresses of the two tokens.
    * `amountADesired`, `amountBDesired`: Desired amounts of tokens to add.
    * `amountAMin`, `amountBMin`: Minimum acceptable amounts to prevent slippage.
    * `to`: Address to receive the liquidity tokens.
    * `deadline`: Timestamp by which the transaction must be processed.
* **Returns:**
    * `amountA`, `amountB`: Actual amounts of tokens A and B added.
    * `liquidity`: Amount of liquidity tokens minted.

### 2. Remove Liquidity (`removeLiquidity`)

* **Description:** Enables users to withdraw liquidity from an ERC-20 liquidity pool.
* **Interface:**
    ```solidity
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
    ```
* **Tasks:**
    * Burns liquidity tokens from the user's balance.
    * Calculates and returns proportional amounts of token A and token B.
* **Parameters:**
    * `tokenA`, `tokenB`: Addresses of the tokens in the pair.
    * `liquidity`: Amount of liquidity tokens to burn/withdraw.
    * `amountAMin`, `amountBMin`: Minimum acceptable amounts of tokens A and B to receive.
    * `to`: Address to receive the withdrawn tokens.
    * `deadline`: Timestamp by which the transaction must be processed.
* **Returns:**
    * `amountA`, `amountB`: Amounts of tokens A and B received after removing liquidity.

### 3. Swap Tokens (`swapExactTokensForTokens`)

* **Description:** Allows users to swap an exact amount of one token for another.
* **Interface:**
    ```solidity
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path, // [tokenIn, tokenOut]
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
    ```
* **Tasks:**
    * Transfers the input token from the user to the contract.
    * Calculates the swap amount based on the pool's reserves and applies a fee.
    * **Calls an external `IVerificador` contract to verify the swap before execution.**
    * Transfers the output token to the user.
* **Parameters:**
    * `amountIn`: Exact amount of input tokens to send.
    * `amountOutMin`: Minimum acceptable amount of output tokens to receive.
    * `path`: An array of token addresses defining the swap route (currently only direct swaps `[tokenIn, tokenOut]` are supported).
    * `to`: Address to receive the output tokens.
    * `deadline`: Timestamp by which the transaction must be processed.
* **Returns:**
    * `amounts`: An array containing the input and output amounts `[amountIn, amountOut]`.

### 4. Get Price (`getPrice`)

* **Description:** Retrieves the current price of one token in terms of another for a given pair.
* **Interface:**
    ```solidity
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price);
    ```
* **Tasks:**
    * Fetches the reserves of both tokens in the specified pair.
    * Calculates and returns the price (scaled by $10^{18}$).
* **Parameters:**
    * `tokenA`, `tokenB`: Addresses of the two tokens in the pair.
* **Returns:**
    * `price`: The price of `tokenA` in terms of `tokenB`.

### 5. Get Amount Out (`getAmountOut`)

* **Description:** Calculates the expected amount of output tokens received for a given input token amount.
* **Interface:**
    ```solidity
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);
    ```
* **Tasks:**
    * Calculates the output amount applying the swap fee.
* **Parameters:**
    * `amountIn`: Amount of input tokens.
    * `reserveIn`, `reserveOut`: Current reserves of the input and output tokens in the pool.
* **Returns:**
    * `amountOut`: The calculated amount of output tokens to be received.

---

## 🛠️ Technologies Used

* **Solidity:** Smart contract programming language.
* **Hardhat (Recommended):** For local development, testing, and deployment.
* **OpenZeppelin Contracts:** Utilized for secure and audited functionalities like `IERC20`, `ReentrancyGuard`, and `Ownable`.

---

## 🚀 Getting Started

### Prerequisites

* Node.js (LTS version)
* npm or yarn
* Git

### Installation

1.  **Clone the repository:**
    ```bash
    git clone [https://github.com/tu-usuario/simple-swap.git](https://github.com/tu-usuario/simple-swap.git)
    cd simple-swap
    ```
2.  **Install dependencies (if using Hardhat for testing/deployment):**
    ```bash
    npm install # or yarn install
    ```

### Deployment

To deploy this contract, you'll typically use a tool like Hardhat or Remix.

1.  **Set up your environment variables** (e.g., `PRIVATE_KEY`, `ALCHEMY_API_KEY`) if deploying to a testnet or mainnet.
2.  **Compile the contract:**
    ```bash
    npx hardhat compile
    ```
3.  **Deploy using a deployment script (e.g., `scripts/deploy.js`):**
    ```javascript
    // scripts/deploy.js
    const { ethers } = require("hardhat");

    async function main() {
      const [deployer] = await ethers.getSigners();
      console.log("Deploying contracts with the account:", deployer.address);

      // Deploy the Verificador contract first (replace with your actual Verificador contract if separate)
      // Make sure you have Verificador.sol defined in your contracts folder.
      const Verificador = await ethers.getContractFactory("Verificador"); 
      const verificador = await Verificador.deploy();
      await verificador.waitForDeployment();
      console.log("Verificador deployed to:", verificador.target);

      // Deploy SimpleSwap, passing the Verificador address
      const SimpleSwap = await ethers.getContractFactory("SimpleSwap");
      const simpleSwap = await SimpleSwap.deploy(verificador.target);
      await simpleSwap.waitForDeployment();
      console.log("SimpleSwap deployed to:", simpleSwap.target);
    }

    main()
      .then(() => process.exit(0))
      .catch((error) => {
        console.error(error);
        process.exit(1);
      });
    ```
    Then run:
    ```bash
    npx hardhat run scripts/deploy.js --network <your-network> # e.g., --network sepolia
    ```

### Usage

After deployment, you can interact with the `SimpleSwap` contract using tools like Hardhat's console, Ethers.js, Web3.js, or Remix.

**Example Interaction (conceptual using Ethers.js):**

```javascript
const { ethers } = require("hardhat");

async function interact() {
    const simpleSwapAddress = "YOUR_DEPLOYED_SIMPLESWAP_ADDRESS";
    const simpleSwap = await ethers.getContractAt("SimpleSwap", simpleSwapAddress);

    // Assuming you have ERC20 token instances deployed (e.g., TokenA, TokenB)
    const tokenAAddress = "YOUR_TOKEN_A_ADDRESS";
    const tokenBAddress = "YOUR_TOKEN_B_ADDRESS";
    const tokenA = await ethers.getContractAt("IERC20", tokenAAddress);
    const tokenB = await ethers.getContractAt("IERC20", tokenBAddress);

    const signer = (await ethers.getSigners())[0];

    // --- Add Liquidity ---
    const amountADesired = ethers.parseUnits("100", 18); // Example: 100 tokens
    const amountBDesired = ethers.parseUnits("200", 18); // Example: 200 tokens
    const amountAMin = ethers.parseUnits("90", 18);
    const amountBMin = ethers.parseUnits("180", 18);
    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes from now

    // Approve SimpleSwap to transfer tokens from your account
    await tokenA.connect(signer).approve(simpleSwapAddress, amountADesired);
    await tokenB.connect(signer).approve(simpleSwapAddress, amountBDesired);

    console.log("Adding liquidity...");
    const txAdd = await simpleSwap.connect(signer).addLiquidity({
        tokenA: tokenAAddress,
        tokenB: tokenBAddress,
        amountADesired: amountADesired,
        amountBDesired: amountBDesired,
        amountAMin: amountAMin,
        amountBMin: amountBMin,
        to: signer.address,
        deadline: deadline
    });
    await txAdd.wait();
    console.log("Liquidity added!");

    // --- Swap Tokens ---
    const swapAmountIn = ethers.parseUnits("10", 18);
    const swapAmountOutMin = ethers.parseUnits("19", 18); // Expect at least 19 B for 10 A
    const path = [tokenAAddress, tokenBAddress];

    await tokenA.connect(signer).approve(simpleSwapAddress, swapAmountIn);

    console.log("Swapping tokens...");
    const txSwap = await simpleSwap.connect(signer).swapExactTokensForTokens(
        swapAmountIn,
        swapAmountOutMin,
        path,
        signer.address,
        deadline
    );
    await txSwap.wait();
    console.log("Tokens swapped!");

    // --- Get Price ---
    const price = await simpleSwap.getPrice(tokenAAddress, tokenBAddress);
    console.log("Price of TokenA in terms of TokenB:", price.toString());

    // --- Get Pair Info ---
    const [reserveA, reserveB, totalSupply, exists] = await simpleSwap.getPairInfo(tokenAAddress, tokenBAddress);
    console.log(`Pair Info: Reserves A=${reserveA}, B=${reserveB}, Total Supply=${totalSupply}, Exists=${exists}`);
}

// interact().catch(console.error);
