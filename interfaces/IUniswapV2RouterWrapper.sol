// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

interface IUniswapV2RouterWrapper {
    function wrappedSwapExactTokensForTokens(
        address _router,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _addresses,
        address _to,
        uint256 _deadline
    ) external returns (uint[] memory amounts);
}
