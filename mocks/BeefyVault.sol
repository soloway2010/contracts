// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;

import "../utils/ERC20.sol";

contract BeefyVault is ERC20 {
    address public want;

    constructor(address _want, string memory name, string memory symbol, uint8 decimals_) public ERC20(name, symbol, decimals_) {
        want = _want;
    }

    function deposit(uint256 amount) external {
        IERC20(want).transferFrom(msg.sender, address(this), amount);
        _mint(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);

        require(IERC20(want).balanceOf(address(this)) >= amount, "Vault: Not enough want token to transfer");
        IERC20(want).transfer(msg.sender, amount);
    }
}
