// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;


import "./SimpleSwaps.sol";

/**
 * @title VerifierMock
 * @notice A mock contract implementing the IVerifier interface for testing purposes.
 * @dev In a real-world scenario, this contract would contain complex logic
 * to validate various swap parameters (e.g., price impact, blacklist checks, etc.).
 * For this test/assignment, it simply returns true, allowing swaps to proceed.
 */
contract VerifierMock is IVerificador {
    /**
     * @notice Implements the verification logic for a swap.
     * @dev This mock implementation always returns true, simulating a successful verification.
     * It serves as a placeholder for actual complex verification rules.
     * @param tokenIn Address of the token being swapped in.
     * @param tokenOut Address of the token being swapped out.
     * @param amountIn Amount of the input token.
     * @param amountOut Amount of the output token.
     * @return true indicating that the swap passes verification.
     */
    function verificarSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    ) external pure override returns (bool) {
        
        require(tokenIn != address(0) && tokenOut != address(0), "Verifier: Invalid token address");
        require(amountIn > 0, "Verifier: Amount in must be greater than zero");
        require(amountOut > 0, "Verifier: Amount out must be greater than zero");
        
        return true;
    }
}