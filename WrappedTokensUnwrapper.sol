pragma solidity 0.6.4;

import "./interfaces/IWrappedTokensUnwrapper.sol";
import "./interfaces/IERC20.sol";
import "./utils/Ownable.sol";

contract WrappedTokensUnwrapper is Ownable
{
    address payable public handlerAddress;

    function setHandlerAddress(address payable _handlerAdddress) public onlyOwner {
        handlerAddress = _handlerAdddress;
    }

    receive() external payable {}

    constructor(address payable _handlerAdddress) public {
        handlerAddress = _handlerAdddress;
    }

    function unwrap(address WETH) public {
        require(msg.sender == handlerAddress, "Only handler can unwrap wrapped tokens");

        uint256 balance = IERC20(WETH).balanceOf(address(this));
        IWETH(WETH).withdraw(balance);
        (bool success, ) = handlerAddress.call{value: balance}("");
        require(success, "Transfer failed.");
    }
}
