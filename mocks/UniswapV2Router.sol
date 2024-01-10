// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../utils/ERC20.sol";

contract UniswapV2Router {
    mapping(address => mapping(address => address)) public pairs;
    address public factory;

    function setPair(
        address tokenA,
        address tokenB,
        address pair
    ) public {
        pairs[tokenA][tokenB] = pair;
        pairs[tokenB][tokenA] = pair;
    }

    function setFactory(address _factory) public {
        factory = _factory;
    }

    constructor(
        address _factory
    ) public {
        factory = _factory;
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public view returns (uint256 amountB) {
        amountB = amountA * reserveB / reserveA;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        address token0,
        address token1
    ) public view returns (uint256 amountOut) {
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn;

        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        require(IERC20(path[1]).balanceOf(address(this)) >= amountIn, "Router: Not enough path[1] token to transfer");
        IERC20(path[1]).transfer(msg.sender, amountIn);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public returns (uint amountA, uint amountB, uint liquidity) {
        amountA = amountADesired;
        amountB = amountBDesired;
        liquidity = (amountA < amountB ? amountA : amountB);

        address pair = pairs[tokenA][tokenB];

        IERC20(tokenA).transferFrom(msg.sender, pair, amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, pair, amountBDesired);

        require(IERC20(pair).balanceOf(address(this)) >= liquidity, "Router: Not enough pair token to transfer");
        IERC20(pair).transfer(to, liquidity);
    }
}
