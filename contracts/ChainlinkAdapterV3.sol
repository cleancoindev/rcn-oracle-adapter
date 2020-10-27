pragma solidity ^0.6.6;

import "./commons/Ownable.sol";
import "./interfaces/AggregatorV3Interface.sol";
import "./utils/SafeMath.sol";
import "./utils/StringUtils.sol";
import "./interfaces/IOracleAdapter.sol";


contract ChainlinkAdapterV3 is Ownable, IOracleAdapter {
    using SafeMath for uint256;
    using StringUtils for string;

    mapping(bytes32 => mapping(bytes32 => address)) public aggregators;

    event SetAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);
    event RemoveAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);

    function symbolToBytes32(string calldata _symbol) external pure returns (bytes32) {
        return _symbol.toBytes32();
    }

    function setAggregator(
        bytes32 _symbolA,
        bytes32 _symbolB,
        address _aggregator
    ) external override onlyOwner {
        require(_aggregator != address(0), "ChainLinkAdapter/Aggregator 0x0 is not valid");
        require(aggregators[_symbolA][_symbolB] == address(0), "ChainLinkAdapter/Aggregator is already set");

        aggregators[_symbolA][_symbolB] = _aggregator;
        emit SetAggregator(
            _symbolA,
            _symbolB,
            _aggregator
        );
    }

    function removeAggregator(
        bytes32 _symbolA,
        bytes32 _symbolB
    ) external override onlyOwner {
        address remAggregator = aggregators[_symbolA][_symbolB];
        require(remAggregator != address(0), "ChainLinkAdapter/Aggregator not set");

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
        address directRate = aggregators[_symbolA][_symbolB];
        address reverseRate = aggregators[_symbolB][_symbolA];
        require(directRate != address(0) || reverseRate != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");

        AggregatorV3Interface aggregator;
        if (directRate != address(0)) {
            aggregator = AggregatorV3Interface(directRate);
        } else {
            aggregator = AggregatorV3Interface(reverseRate);
        }
        (,,,lastTimestamp,) = aggregator.latestRoundData();
    }

    function getRate(bytes32[] calldata path) external override view returns (uint256 combinedRate)  {
        uint256 prevRate;
        uint8 prevDec;
        for (uint i; i < path.length - 1; i++) {
            (bytes32 input, bytes32 output) = (path[i], path[i + 1]);
            (uint256 rate0, uint8 decimals) = _getPairRate(input, output);
            combinedRate = prevRate > 0 ? _getCombined(prevRate, rate0, prevDec) : rate0;
            prevRate = combinedRate;
            prevDec = decimals;
        }
    }

    function getPairLastRate(bytes32 _symbolA, bytes32 _symbolB) public view returns (uint256 answer)  {
        AggregatorV3Interface aggregator = AggregatorV3Interface(aggregators[_symbolA][_symbolB]);
        (,int256 rate,,,) = aggregator.latestRoundData();
        answer = uint256(rate);
    }

    function _getPairRate(bytes32 _input, bytes32 _output) private view returns (uint256 rate, uint8 decimals) {
        address directRate = aggregators[_input][_output];
        address reverseRate = aggregators[_output][_input];
        require(directRate != address(0) || reverseRate != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");

        decimals = getDecimals(_input, _output);
        if (directRate != address(0)) {
            rate = getPairLastRate(_input, _output);
        } else {
            rate = (10**(uint256(decimals)*2)).div(getPairLastRate(_output, _input));
        }
    }

    function _getCombined(uint256 rate0, uint256 rate1, uint8 _decimal) private pure returns (uint256 combinedRate) {
        combinedRate = rate0.mult(rate1).div(10 ** uint256(_decimal));
    }

    function getDecimals(bytes32 _input, bytes32 _output) public view returns (uint8 decimals) {
        address directRate = aggregators[_input][_output];
        address reverseRate = aggregators[_output][_input];
        require(directRate != address(0) || reverseRate != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");
        AggregatorV3Interface aggregator;
        if (directRate != address(0)) {
            aggregator = AggregatorV3Interface(directRate);
        } else {
            aggregator = AggregatorV3Interface(reverseRate);
        }
        decimals = aggregator.decimals();
    }
}
