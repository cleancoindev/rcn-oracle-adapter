pragma solidity ^0.6.6;

import "../interfaces/AggregatorInterface.sol";


contract FakeAggregator is AggregatorInterface {

    int256 public lastAnswer;
    string public symbolA;
    string public symbolB;

    constructor (string memory _symbolA, string memory _symbolB) public {
        symbolA = _symbolA;
        symbolB = _symbolB;
    }

    function setLatestAnswer(int256 _answer) external {
        lastAnswer = _answer;
    }

    function latestAnswer() external override view returns (int256) {
        return lastAnswer;
    }

    function latestTimestamp() external override view returns (uint256) {
        return 0;
    }

    function latestRound() external override view returns (uint256) {
        return 0;
    }

    function getAnswer(uint256 roundId) external override view returns (int256) {
        return int256(roundId);
    }

    function getTimestamp(uint256 roundId) external override view returns (uint256) {
        return roundId;
    }
}