pragma solidity ^0.6.6;


interface IOracleAdapter {

  function setAggregator(
    bytes32 _symbolA,
    bytes32 _symbolB,
    address _aggregator
  ) external;

  function removeAggregator(bytes32 _symbolA, bytes32 _symbolB) external;
  function getRate (bytes32[] calldata path) external view returns (uint256);
  function latestTimestamp (bytes32[] calldata path) external view returns (uint256);
  function getDecimals (bytes32 _symbolA, bytes32 _symbolB) external view returns (uint8);

  event RemoveAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);
  event SetAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);
}