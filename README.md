# 🔄 SimpleSwap - AMM Smart Contract

A lightweight Automated Market Maker (AMM) smart contract for ERC-20 token swaps and liquidity provision, inspired by Uniswap V2, with external swap verification.

## 🚀 Features

- Direct token swaps (`tokenIn → tokenOut`)
- Swap verification via an external contract (`IVerificador`)
- Add/remove liquidity to/from custom token pairs
- Internal reserve and liquidity balance management
- Reentrancy protection using `ReentrancyGuard`
- Access control for critical updates (verifier) with `Ownable`

---

## 📦 Contract Structure

- `SimpleSwap.sol`: Main contract containing swap logic, liquidity management, and view functions.
- `IVerificador`: External interface for customizable swap verification logic.

---

## 🛠️ Requirements

- Solidity `^0.8.19`
- OpenZeppelin Contracts (`@openzeppelin/contracts`)
  - `IERC20`
  - `Ownable`
  - `ReentrancyGuard`

Install dependencies:
```bash
npm install @openzeppelin/contracts
