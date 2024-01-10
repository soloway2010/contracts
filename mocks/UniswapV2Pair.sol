// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "../utils/ERC20.sol";

contract UniswapV2Pair is ERC20  {
    address public factory;
    address public token0;
    address public token1;

    function setToken0(
        address _token0
    ) public {
        token0 = _token0;
    }

    function setToken1(
        address _token1
    ) public {
        token1 = _token1;
    }

    function setFactory(address _factory) public {
        factory = _factory;
    }

    constructor(
        address _factory,
        address _token0,
        address _token1,
        string memory name,
        string memory symbol,
        uint8 decimals_
    ) public ERC20(name, symbol, decimals_) {
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
    
    function burn(address to) public returns (uint amount0, uint amount1) {
        amount0 = balanceOf(address(this));
        amount1 = amount0;

        _burn(address(this), amount0);

        require(IERC20(token0).balanceOf(address(this)) >= amount0, "Pair: Not enough token0 token to transfer");
        IERC20(token0).transfer(to, amount0);

        require(IERC20(token1).balanceOf(address(this)) >= amount1, "Pair: Not enough token1 token to transfer");
        IERC20(token1).transfer(to, amount1);
    }
    
    function getReserves() public view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) {
        reserve0 = 0xffffffffffffffffffffffffffff;
        reserve1 = reserve0;
        blockTimestampLast = uint32(block.timestamp);
    }
}
