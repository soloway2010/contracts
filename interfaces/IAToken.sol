pragma solidity 0.6.4;

interface IAToken {
  function scaledBalanceOf(address user) external view returns (uint256);
}
