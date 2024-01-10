pragma solidity 0.6.4;
pragma experimental ABIEncoderV2;

import { DataTypes } from '../libraries/DataTypes.sol';

interface ILendingPool {
  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

  function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}
