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
    mapping(bytes32 => uint8) public multiplier;

    event SetAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator, uint8 _multiplierA, uint8 _multiplierB);
    event RemoveAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);
    event SetMultiplier(bytes32 _symbol, uint8 _multiplier);

    function symbolToBytes32(string calldata _symbol) external pure returns (bytes32) {
        return _symbol.toBytes32();
    }

    function getMultiplier (bytes32 _symbol) external override view returns (uint256) {
        return 10 ** uint256(multiplier[_symbol]);
    }

    function setMultiplier(bytes32 _symbol, uint8 _multiplier) external override onlyOwner {
        multiplier[_symbol] = _multiplier;
        emit SetMultiplier(_symbol, _multiplier);
    }

    function setAggregator(
        bytes32 _symbolA,
        bytes32 _symbolB,
        address _aggregator,
        uint8 _multiplierA,
        uint8 _multiplierB
    ) external override onlyOwner {
        require(_aggregator != address(0), "ChainLinkAdapter/Aggregator 0x0 is not valid");
        require(aggregators[_symbolA][_symbolB] == address(0), "ChainLinkAdapter/Aggregator is already set");

        aggregators[_symbolA][_symbolB] = _aggregator;
        if (multiplier[_symbolA] == 0) {
            multiplier[_symbolA] = _multiplierA;
        }
        if (multiplier[_symbolA] == 0) {
            multiplier[_symbolB] = _multiplierB;
        }

        emit SetAggregator(
            _symbolA,
            _symbolB,
            _aggregator,
            _multiplierA,
            _multiplierB
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
        AggregatorV3Interface aggregator;
        if (aggregators[_symbolA][_symbolB] != address(0)) {
            aggregator = AggregatorV3Interface(aggregators[_symbolA][_symbolB]);
        } else {
            aggregator = AggregatorV3Interface(aggregators[_symbolB][_symbolA]);
        }
        (,,,lastTimestamp,) = aggregator.latestRoundData();
    }

    function getRate (bytes32[] calldata path) external override view returns (uint256 combinedRate)  {
        uint256 prevRate;
        for (uint i; i < path.length - 1; i++) {
            (bytes32 input, bytes32 output) = (path[i], path[i + 1]);
            (uint256 rate0) = _getPairRate(input, output);
            combinedRate = prevRate > 0 ? _getCombined(prevRate, rate0, multiplier[input]) : rate0;
            prevRate = combinedRate;
        }
    }

    function getPairLastRate (bytes32 _symbolA, bytes32 _symbolB) public view returns (uint256 answer)  {
        AggregatorV3Interface aggregator = AggregatorV3Interface(aggregators[_symbolA][_symbolB]);
        (,int256 rate,,,) = aggregator.latestRoundData();
        answer = uint256(rate);
    }

    function _getPairRate(bytes32 input, bytes32 output) private view returns (uint256 rate) {
        require(aggregators[input][output] != address(0) || aggregators[output][input] != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");

        if (aggregators[input][output] != address(0)) {
            rate = getPairLastRate(input, output);
        } else {
            uint256 multiplier0 = 10 ** uint256(multiplier[input]);
            uint256 multiplier1 = 10 ** uint256(multiplier[output]);
            rate = multiplier0.mult(multiplier1).div(getPairLastRate(output, input));
        }
    }

    function _getCombined(uint256 rate0, uint256 rate1, uint8 _multiplier0) private pure returns (uint256 combinedRate) {
        combinedRate = rate0.mult(rate1).div(10 ** uint256(_multiplier0));
    }
}

