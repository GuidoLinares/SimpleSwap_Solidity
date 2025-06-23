// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title IVerificador
 * @notice Interface for swap verification contract
 */
interface IVerificador {
    function verificarSwap(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut) external view returns (bool);
}

/**
 * @title SimpleSwap
 * @notice A simple automated market maker (AMM) for token swapping and liquidity provision
 * @dev Implements core AMM functionality similar to Uniswap V2
 */
contract SimpleSwap is ReentrancyGuard, Ownable {
    
    /// @notice Emitted when liquidity is added to a pair
    event LiquidityAdded(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity, address indexed to);
    
    /// @notice Emitted when liquidity is removed from a pair
    event LiquidityRemoved(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity, address indexed to);
    
    /// @notice Emitted when tokens are swapped
    event TokensSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address indexed to);

    /// @notice Address of the verification contract
    address public verificador;

    /**
     * @notice Constructor to initialize the SimpleSwap contract
     * @param _verificador Address of the verification contract
     */
    constructor(address _verificador) Ownable(msg.sender) {
        verificador = _verificador;
    }

    /**
     * @notice Struct representing a trading pair
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @param reserveA Reserve amount of tokenA
     * @param reserveB Reserve amount of tokenB
     * @param totalSupply Total liquidity supply for this pair
     * @param liquidityBalances Mapping of user addresses to their liquidity balances
     */
    struct Pair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        mapping(address => uint256) liquidityBalances;
    }

    /**
     * @notice Parameters for adding liquidity
     */
    struct LiquidityParams {
        address tokenA;
        address tokenB;
        uint256 amountADesired;
        uint256 amountBDesired;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
        uint256 deadline;
    }

    /**
     * @notice Parameters for removing liquidity
     */
    struct RemoveParams {
        address tokenA;
        address tokenB;
        uint256 liquidity;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
        uint256 deadline;
    }

    /// @notice Mapping of pair keys to Pair structs
    mapping(bytes32 => Pair) private pairs;
    
    /// @notice Mapping to check if a pair exists
    mapping(bytes32 => bool) private pairExists;

    /// @notice Minimum liquidity to prevent division by zero
    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    
    /// @notice Fee rate (0.3% fee = 997/1000)
    uint256 private constant FEE_RATE = 997;

    /**
     * @notice Modifier to check if transaction deadline has not passed
     * @param deadline Transaction deadline timestamp
     */
    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }

    /**
     * @notice Modifier to validate token addresses
     * @param tokenA First token address
     * @param tokenB Second token address
     */
    modifier validTokens(address tokenA, address tokenB) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token");
        require(tokenA != tokenB, "Identical tokens");
        _;
    }

    /**
     * @notice Generate a unique key for a token pair
     * @param tokenA First token address
     * @param tokenB Second token address
     * @return Unique bytes32 key for the pair
     */
    function getPairKey(address tokenA, address tokenB) public pure returns (bytes32) {
        return tokenA < tokenB ? keccak256(abi.encodePacked(tokenA, tokenB)) : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /**
     * @notice Add liquidity to a token pair
     * @param params LiquidityParams struct containing all necessary parameters
     * @return amountA Actual amount of tokenA added
     * @return amountB Actual amount of tokenB added
     * @return liquidity Amount of liquidity tokens minted
     */
    function addLiquidity(
        LiquidityParams calldata params
    ) external nonReentrant checkDeadline(params.deadline) validTokens(params.tokenA, params.tokenB)
      returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        bytes32 pairKey = getPairKey(params.tokenA, params.tokenB);
        if (!pairExists[pairKey]) {
            Pair storage newPair = pairs[pairKey];
            (newPair.tokenA, newPair.tokenB) = params.tokenA < params.tokenB
                ? (params.tokenA, params.tokenB)
                : (params.tokenB, params.tokenA);
            pairExists[pairKey] = true;
        }

        Pair storage pair = pairs[pairKey];
        (amountA, amountB) = _calculateLiquidityAmounts(
            params.tokenA,
            params.amountADesired,
            params.amountBDesired,
            params.amountAMin,
            params.amountBMin,
            pair
        );

        require(amountA > 0 && amountB > 0, "Insufficient liquidity amounts");

        IERC20(params.tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(params.tokenB).transferFrom(msg.sender, address(this), amountB);

        pair.reserveA += amountA;
        pair.reserveB += amountB;

        liquidity = sqrt(amountA * amountB);
        require(liquidity > MINIMUM_LIQUIDITY, "Insufficient liquidity");

        pair.totalSupply += liquidity;
        pair.liquidityBalances[params.to] += liquidity;

        emit LiquidityAdded(params.tokenA, params.tokenB, amountA, amountB, liquidity, params.to);
    }

    /**
     * @notice Remove liquidity from a token pair
     * @param params RemoveParams struct containing all necessary parameters
     * @return amountA Amount of tokenA returned
     * @return amountB Amount of tokenB returned
     */
    function removeLiquidity(
        RemoveParams calldata params
    ) external nonReentrant checkDeadline(params.deadline) validTokens(params.tokenA, params.tokenB)
      returns (uint256 amountA, uint256 amountB)
    {
        bytes32 pairKey = getPairKey(params.tokenA, params.tokenB);
        require(pairExists[pairKey], "Pair does not exist");

        Pair storage pair = pairs[pairKey];
        require(pair.liquidityBalances[msg.sender] >= params.liquidity, "Insufficient liquidity balance");

        (amountA, amountB) = _calculateRemoveLiquidityAmounts(params.liquidity, pair);

        require(amountA >= params.amountAMin && amountB >= params.amountBMin, "Insufficient amounts");

        pair.liquidityBalances[msg.sender] -= params.liquidity;
        pair.totalSupply -= params.liquidity;

        // Modificación clave aquí para asegurar que las reservas se actualicen correctamente
        // y que la transferencia de tokens coincida con lo que se calculó
        if (params.tokenA == pair.tokenA) {
            pair.reserveA -= amountA;
            pair.reserveB -= amountB;
            IERC20(params.tokenA).transfer(params.to, amountA);
            IERC20(params.tokenB).transfer(params.to, amountB);
        } else {
            // Si params.tokenA no es pair.tokenA, entonces los roles de amountA y amountB se invierten
            // respecto a las reservas del par.
            pair.reserveA -= amountB; // amountB corresponde a pair.tokenA
            pair.reserveB -= amountA; // amountA corresponde a pair.tokenB
            IERC20(params.tokenA).transfer(params.to, amountA);
            IERC20(params.tokenB).transfer(params.to, amountB);
        }

        emit LiquidityRemoved(params.tokenA, params.tokenB, amountA, amountB, params.liquidity, params.to);
    }

    /**
     * @notice Swap exact amount of tokens for tokens
     * @param amountIn Exact amount of input tokens
     * @param amountOutMin Minimum amount of output tokens
     * @param path Array of token addresses [tokenIn, tokenOut]
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline timestamp
     * @return amounts Array containing input and output amounts
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] memory path,
        address to,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) returns (uint256[] memory amounts) {
        require(path.length == 2, "Only direct swap supported");
        require(path[0] != address(0) && path[1] != address(0), "Invalid token addresses");
        require(path[0] != path[1], "Identical tokens");

        bytes32 pairKey = getPairKey(path[0], path[1]);
        require(pairExists[pairKey], "Pair does not exist");

        Pair storage pair = pairs[pairKey];
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(path[0], path[1], pair);

        // Calculate expected output amount
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // CRITICAL: Call verificador BEFORE executing the swap
        require(
            IVerificador(verificador).verificarSwap(path[0], path[1], amountIn, amountOut),
            "Swap not verified by verificador"
        );

        // Prepare amounts array for return
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        // Execute the swap after verification
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        _updateReserves(path[0], path[1], amounts[0], amounts[1], pair);
        IERC20(path[1]).transfer(to, amounts[1]);

        emit TokensSwapped(path[0], path[1], amounts[0], amounts[1], to);
        
        return amounts;
    }

    /**
     * @notice Get the price of tokenA in terms of tokenB
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @return price Price of tokenA in terms of tokenB (scaled by 1e18)
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        require(pairExists[pairKey], "Pair does not exist");

        Pair storage pair = pairs[pairKey];
        uint256 reserveA = pair.tokenA == tokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveB = pair.tokenB == tokenB ? pair.reserveB : pair.reserveA;

        require(reserveB > 0, "Division by zero");
        price = reserveA * 1e18 / reserveB;
    }

    /**
     * @notice Calculate output amount for a given input amount
     * @param amountIn Input token amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Output token amount
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        uint256 amountInWithFee = amountIn * FEE_RATE;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @notice Quote function to calculate proportional amounts
     * @param amountA Amount of tokenA
     * @param reserveA Reserve of tokenA
     * @param reserveB Reserve of tokenB
     * @return amountB Proportional amount of tokenB
     */
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, "Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        amountB = amountA * reserveB / reserveA;
    }

    /**
     * @notice Update the verificador address (only owner)
     * @param _newVerificador New verificador contract address
     */
    function updateVerificador(address _newVerificador) external onlyOwner {
        require(_newVerificador != address(0), "Invalid verificador address");
        verificador = _newVerificador;
    }

    /**
     * @notice Get information about a trading pair
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @return reserveA Reserve amount of tokenA
     * @return reserveB Reserve amount of tokenB
     * @return totalSupply Total liquidity supply
     * @return exists Whether the pair exists
     */
    function getPairInfo(address tokenA, address tokenB) external view returns (
        uint256 reserveA,
        uint256 reserveB,
        uint256 totalSupply,
        bool exists
    ) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        exists = pairExists[pairKey];
        
        if (exists) {
            Pair storage pair = pairs[pairKey];
            reserveA = pair.reserveA;
            reserveB = pair.reserveB;
            totalSupply = pair.totalSupply;
        }
    }

    /**
     * @notice Get liquidity balance for a user in a specific pair
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @param user User address
     * @return Liquidity balance of the user
     */
    function getLiquidityBalance(address tokenA, address tokenB, address user) external view returns (uint256) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        require(pairExists[pairKey], "Pair does not exist");
        
        return pairs[pairKey].liquidityBalances[user];
    }

    // Internal function to calculate liquidity amounts based on desired amounts and current reserves
    function _calculateLiquidityAmounts(
        address _tokenA,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        Pair storage _pair
    ) internal view returns (uint256 amountA, uint256 amountB) {
        if (_pair.reserveA == 0 && _pair.reserveB == 0) {
            (amountA, amountB) = _tokenA == _pair.tokenA
                ? (_amountADesired, _amountBDesired)
                : (_amountBDesired, _amountADesired);
        } else {
            uint256 amountBOptimal = quote(_amountADesired, _pair.reserveA, _pair.reserveB);
            if (amountBOptimal <= _amountBDesired) {
                require(amountBOptimal >= _amountBMin, "Insufficient B amount (A optimal)");
                (amountA, amountB) = _tokenA == _pair.tokenA
                    ? (_amountADesired, amountBOptimal)
                    : (amountBOptimal, _amountADesired);
            } else {
                uint256 amountAOptimal = quote(_amountBDesired, _pair.reserveB, _pair.reserveA);
                require(amountAOptimal <= _amountADesired && amountAOptimal >= _amountAMin, "Insufficient A amount (B optimal)");
                (amountA, amountB) = _tokenA == _pair.tokenA
                    ? (amountAOptimal, _amountBDesired)
                    : (_amountBDesired, amountAOptimal);
            }
        }
    }

    // Internal function to calculate amounts of tokens to return when removing liquidity
    function _calculateRemoveLiquidityAmounts(uint256 liquidity, Pair storage pair) internal view returns (uint256 amountA, uint256 amountB) {
        uint256 reserveA = pair.reserveA;
        uint256 reserveB = pair.reserveB;
        uint256 totalSupply = pair.totalSupply;

        amountA = liquidity * reserveA / totalSupply;
        amountB = liquidity * reserveB / totalSupply;
    }

    // Internal function to get reserves for a given input token
    function _getReserves(address tokenIn, address /* tokenOut */, Pair storage pair) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        (reserveIn, reserveOut) = tokenIn == pair.tokenA 
            ? (pair.reserveA, pair.reserveB) 
            : (pair.reserveB, pair.reserveA);
    }

    // Internal function to update reserves after a swap
    function _updateReserves(address tokenIn, address /* tokenOut */, uint256 amountIn, uint256 amountOut, Pair storage pair) internal {
        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveB += amountIn;
            pair.reserveA -= amountOut;
        }
    }

    /**
     * @notice Calculate square root using Babylonian method
     * @param y Input value
     * @return z Square root of y
     */
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}