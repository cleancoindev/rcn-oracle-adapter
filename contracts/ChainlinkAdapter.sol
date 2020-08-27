pragma solidity ^0.6.6;

import "./commons/Ownable.sol";
import "./interfaces/AggregatorInterface.sol";
import "./utils/SafeMath.sol";
import "./utils/StringUtils.sol";
import "./interfaces/IOracleAdapter.sol";


contract ChainlinkAdapter is Ownable, IOracleAdapter {
    using SafeMath for uint256;
    using StringUtils for string;

    mapping(bytes32 => mapping(bytes32 => address)) public aggregators;
    mapping(bytes32 => uint8) public decimals;

    event SetAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator, uint8 _decimalsA, uint8 _decimalsB);
    event RemoveAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);

    function symbolToBytes32(string calldata _symbol) external pure returns (bytes32) {
        return _symbol.toBytes32();
    }

    function getAddedDecimals (bytes32 _symbol) external override view returns (uint256) {
        return 10 ** uint256(decimals[_symbol]);
    }

    function setAggregator(
        bytes32 _symbolA,
        bytes32 _symbolB,
        address _aggregator,
        uint8 _decimalsA,
        uint8 _decimalsB
    ) external override onlyOwner {
        require(_aggregator != address(0), "ChainLinkAdapter/Aggregator 0x0 is not valid");
        require(aggregators[_symbolA][_symbolB] == address(0), "ChainLinkAdapter/Aggregator is already set");

        aggregators[_symbolA][_symbolB] = _aggregator;
        decimals[_symbolA] = _decimalsA;
        decimals[_symbolB] = _decimalsB;

        emit SetAggregator(
            _symbolA,
            _symbolB,
            _aggregator,
            _decimalsA,
            _decimalsB
        );
    }

    function removeAggregator(
        bytes32 _symbolA,
        bytes32 _symbolB
    ) external override onlyOwner {
        require(aggregators[_symbolA][_symbolB] != address(0), "ChainLinkAdapter/Aggregator not set");

        address remAggregator = aggregators[_symbolA][_symbolB];
        aggregators[_symbolA][_symbolB] = address(0);

        emit RemoveAggregator(
            _symbolA,
            _symbolB,
            remAggregator
        );
    }

    function latestTimestamp(bytes32[] calldata path) external override view returns (uint256 lastTimestamp)  {
        uint256 prevTimestamp;
        for (uint i; i < path.length - 1; i++) {
            (bytes32 input, bytes32 output) = (path[i], path[i + 1]);
            (uint256 timestamp0) = getLatestTimestamp(input, output);
            lastTimestamp = timestamp0 < prevTimestamp || prevTimestamp == 0  ? timestamp0 : prevTimestamp;
            prevTimestamp = lastTimestamp;
        }
    }

    function getLatestTimestamp(bytes32 _symbolA, bytes32 _symbolB) public view returns (uint256 lastTimestamp)  {
        require(aggregators[_symbolA][_symbolB] != address(0) || aggregators[_symbolB][_symbolA] != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");
        AggregatorInterface aggregator;
        if (aggregators[_symbolA][_symbolB] != address(0)) {
            aggregator = AggregatorInterface(aggregators[_symbolA][_symbolB]);
        } else {
            aggregator = AggregatorInterface(aggregators[_symbolB][_symbolA]);
        }
        lastTimestamp = uint256(aggregator.latestTimestamp());
    }

    function getRate (bytes32[] calldata path) external override view returns (uint256 combinedRate)  {
        uint256 prevRate;
        for (uint i; i < path.length - 1; i++) {
            (bytes32 input, bytes32 output) = (path[i], path[i + 1]);
            (uint256 rate0) = _getPairRate(input, output);
            combinedRate = prevRate > 0 ? _getCombined(prevRate, rate0, decimals[input]) : rate0;
            prevRate = combinedRate;
        }
    }

    function getPairLastRate (bytes32 _symbolA, bytes32 _symbolB) public view returns (uint256 answer)  {
        AggregatorInterface aggregator = AggregatorInterface(aggregators[_symbolA][_symbolB]);
        answer = uint256(aggregator.latestAnswer());
    }

    function _getPairRate(bytes32 input, bytes32 output) private view returns (uint256 rate) {
        require(aggregators[input][output] != address(0) || aggregators[output][input] != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");

        if (aggregators[input][output] != address(0)) {
            rate = getPairLastRate(input, output);
        } else {
            uint256 decimals0 = 10 ** uint256(decimals[input]);
            uint256 decimals1 = 10 ** uint256(decimals[output]);
            rate = decimals0.mult(decimals1).div(getPairLastRate(output, input));
        }
    }

    function _getCombined(uint256 rate0, uint256 rate1, uint8 _decimals0) private pure returns (uint256 combinedRate) {
        combinedRate = rate0.mult(rate1).div(10 ** uint256(_decimals0));
    }
}

