pragma solidity ^0.6.6;

import "./commons/Ownable.sol";
import "./interfaces/AggregatorInterface.sol";
import "./utils/SafeMath.sol";
import "./utils/StringUtils.sol";


contract ChainlinkAdapter is Ownable {
    using SafeMath for uint256;
    using StringUtils for string;

    mapping(bytes32 => mapping(bytes32 => address)) public aggregators;
    mapping(bytes32 => uint8) public decimals;
    address[] allAggregators;

    event SetPair(bytes32 _symbolA, bytes32 _symbolB, address _aggregator);
    event SetDecimals(bytes32 _symbol, uint8 _decimals);

    function symbolToBytes32(string calldata _symbol) external pure returns (bytes32) {
        return _symbol.toBytes32();
    }

    function allAggregatorsLength() external view returns (uint) {
        return allAggregators.length;
    }

    function setDecimals(bytes32 _symbol, uint8 _decimals) external {
        decimals[_symbol] = _decimals;
        emit SetDecimals(_symbol, _decimals);
    }

    function setPair(bytes32 _symbolA, bytes32 _symbolB, address aggregator) external {
        aggregators[_symbolA][_symbolB] = aggregator;
        emit SetPair(_symbolA, _symbolB, aggregator);
    }

    function getPairLastRate (bytes32 _symbolA, bytes32 _symbolB) public view returns (uint256 answer)  {
        AggregatorInterface aggregator = AggregatorInterface(aggregators[_symbolA][_symbolB]);
        answer = uint256(aggregator.latestAnswer());
    }

    function getRate (bytes32[] calldata path) external view returns (uint256 combinedRate)  {
        uint256 prevRate;
        for (uint i; i < path.length - 1; i++) {
            (bytes32 input, bytes32 output) = (path[i], path[i + 1]);
            (uint256 rate0) = _getPairRate(input, output);
            combinedRate = prevRate > 0 ? _getCombined(prevRate, rate0, decimals[input]) : rate0;
        }
    }

    function _getPairRate(bytes32 input, bytes32 output) private view returns (uint256 rate) {
        require(aggregators[input][output] != address(0) || aggregators[output][input] != address(0), "ChainLinkAdapter/Aggregator not set, path not resolved");

        if (aggregators[input][output] != address(0)) {
            rate = getPairLastRate(input, output);
        } else {
            uint256 decimals0 = 10 ** uint256(decimals[input]);
            uint256 decimals1 = 10 ** uint256(decimals[output]);
            rate = decimals0.mult(decimals1).div(getPairLastRate(input, output));
        }
    }

    function _getCombined(uint256 rate0, uint256 rate1, uint8 _decimals0) private pure returns (uint256 combinedRate) {
        uint256 decimals0 = 10 ** uint256(_decimals0);
        combinedRate = rate0.mult(rate1).div(decimals0);
    }
}

