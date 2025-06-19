// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SimpleSwap is ReentrancyGuard {
    event LiquidityAdded(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity, address indexed to);
    event LiquidityRemoved(address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity, address indexed to);
    event TokensSwapped(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut, address indexed to);

    struct Pair {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalSupply;
        mapping(address => uint256) liquidityBalances;
    }

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

    struct RemoveParams {
        address tokenA;
        address tokenB;
        uint256 liquidity;
        uint256 amountAMin;
        uint256 amountBMin;
        address to;
        uint256 deadline;
    }

    mapping(bytes32 => Pair) private pairs;
    mapping(bytes32 => bool) private pairExists;

    uint256 private constant MINIMUM_LIQUIDITY = 1000;
    uint256 private constant FEE_RATE = 997; // 0.997 (0.3% fee)

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }

    modifier validTokens(address tokenA, address tokenB) {
        require(tokenA != address(0) && tokenB != address(0), "Invalid token");
        require(tokenA != tokenB, "Identical tokens");
        _;
    }

    function getPairKey(address tokenA, address tokenB) public pure returns (bytes32) {
        return tokenA < tokenB ? keccak256(abi.encodePacked(tokenA, tokenB)) : keccak256(abi.encodePacked(tokenB, tokenA));
    }

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

        _transferTokens(params.tokenA, params.tokenB, amountA, amountB, params.to, pair);

        emit LiquidityRemoved(params.tokenA, params.tokenB, amountA, amountB, params.liquidity, params.to);
    }

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

    function _calculateRemoveLiquidityAmounts(
    uint256 liquidity,
    Pair storage pair
) internal view returns (uint256 amountA, uint256 amountB) {
    uint256 reserveA = pair.reserveA;
    uint256 reserveB = pair.reserveB;
    uint256 totalSupply = pair.totalSupply;

    amountA = liquidity * reserveA / totalSupply;
    amountB = liquidity * reserveB / totalSupply;
}

    function _transferTokens(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        address to,
        Pair storage pair
    ) internal {
        if (tokenA == pair.tokenA) {
            pair.reserveA -= amountA;
            pair.reserveB -= amountB;
            IERC20(tokenA).transfer(to, amountA);
            IERC20(tokenB).transfer(to, amountB);
        } else {
            pair.reserveA -= amountB;
            pair.reserveB -= amountA;
            IERC20(tokenA).transfer(to, amountB);
            IERC20(tokenB).transfer(to, amountA);
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address /*tokenOut*/,
        address to,
        uint256 deadline
    ) external nonReentrant checkDeadline(deadline) returns (uint256 amountOut) {
        bytes32 pairKey = getPairKey(tokenIn, to);
        require(pairExists[pairKey], "Pair does not exist");

        Pair storage pair = pairs[pairKey];
        (uint256 reserveIn, uint256 reserveOut) = _getReserves(tokenIn, to, pair);

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        _updateReserves(tokenIn, to, amountIn, amountOut, pair);
        IERC20(to).transfer(to, amountOut);

        emit TokensSwapped(tokenIn, to, amountIn, amountOut, to);
    }

    function _getReserves(
        address tokenIn,
        address /*tokenOut*/,
        Pair storage pair
    ) internal view returns (uint256 reserveIn, uint256 reserveOut) {
        if (tokenIn == pair.tokenA) {
            reserveIn = pair.reserveA;
            reserveOut = pair.reserveB;
        } else {
            reserveIn = pair.reserveB;
            reserveOut = pair.reserveA;
        }
    }

    function _updateReserves(
        address tokenIn,
        address /*tokenOut*/,        
        uint256 amountIn,
        uint256 amountOut,
        Pair storage pair
    ) internal {
        if (tokenIn == pair.tokenA) {
            pair.reserveA += amountIn;
            pair.reserveB -= amountOut;
        } else {
            pair.reserveA -= amountOut;
            pair.reserveB += amountIn;
        }
    }

    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 pairKey = getPairKey(tokenA, tokenB);
        require(pairExists[pairKey], "Pair does not exist");

        Pair storage pair = pairs[pairKey];
        uint256 reserveA = pair.tokenA == tokenA ? pair.reserveA : pair.reserveB;
        uint256 reserveB = pair.tokenB == tokenB ? pair.reserveA : pair.reserveB;

        price = reserveA * 1e18 / reserveB;
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * FEE_RATE;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) public pure returns (uint256 amountB) {
        require(amountA > 0, "Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        amountB = amountA * reserveB / reserveA;
    }

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
