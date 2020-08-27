pragma solidity ^0.6.6;


interface IOracleAdapter {

  function setAggregator(
    bytes32 _symbolA,
    bytes32 _symbolB,
    address _aggregator,
    uint8 _multiplierA,
    uint8 _multiplierB
  ) external;

  function removeAggregator(bytes32 _symbolA, bytes32 _symbolB) external;
  function getRate (bytes32[] calldata path) external view returns (uint256);
  function latestTimestamp (bytes32[] calldata path) external view returns (uint256);
  function getMultiplier (bytes32 _symbol) external view returns (uint256);
  function setMultiplier (bytes32 _symbol, uint8 _multiplier) external;


  event RemoveAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);
  event SetAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator, uint8 _multiplierA, uint8 _multiplierB);
  event SetMultiplier(bytes32 _symbol, uint8 _multiplier);
}