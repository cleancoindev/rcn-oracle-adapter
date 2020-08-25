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
    address[] allAggregators;

    event SetAggregator(bytes32 _symbolA, bytes32 _symbolB, address _aggregator, uint8 _decimalsA, uint8 _decimalsB);

    function symbolToBytes32(string calldata _symbol) external pure returns (bytes32) {
        return _symbol.toBytes32();
    }

    function allAggregatorsLength() external view returns (uint) {
        return allAggregators.length;
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
        require(_aggregator != address(0), "Aggregator 0x0 is not valid");
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

