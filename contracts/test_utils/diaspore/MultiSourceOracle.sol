pragma solidity ^0.6.6;

import "../../commons/Ownable.sol";
import "../../utils/StringUtils.sol";
import "./RateOracle.sol";
import "../../interfaces/IOracleAdapter.sol";


contract MultiSourceOracle is RateOracle, Ownable {
    using StringUtils for string;

    RateOracle public upgrade;

    uint256 public ibase;
    bytes32[] public path;
    IOracleAdapter public oracleAdapter;

    string private isymbol;
    string private iname;
    uint256 private idecimals;
    address private itoken;
    string private ibaseToken;
    bytes32 private icurrency;
    string private imaintainer;

    constructor(
        IOracleAdapter _oracleAdapter,
        string memory _baseToken,
        uint256 _base,
        string memory _symbol,
        string memory _name,
        uint256 _decimals,
        address _token,
        string memory _maintainer,
        bytes32[] memory _path
    ) public {
        oracleAdapter = _oracleAdapter;
        ibaseToken = _baseToken;
        // Create legacy bytes32 currency
        bytes32 currency = _symbol.toBytes32();
        // Save Oracle metadata
        isymbol = _symbol;
        iname = _name;
        idecimals = _decimals;
        itoken = _token;
        icurrency = currency;
        imaintainer = _maintainer;
        path = _path;
        ibase = _base;
    }

    /**
        3 or 4 letters symbol of the currency, Ej: ETH
    */
    function baseToken() external override virtual view returns (string memory) {
         return ibaseToken;
    }


    /**
     * @return metadata, 3 or 4 letter symbol of the currency provided by this oracle
     *   (ej: ARS)
     * @notice Defined by the RCN RateOracle interface
     */
    function symbol() external override view returns (string memory) {
        return isymbol;
    }

    /**
     * @return metadata, full name of the currency provided by this oracle
     *   (ej: Argentine Peso)
     * @notice Defined by the RCN RateOracle interface
     */
    function name() external override view returns (string memory) {
        return iname;
    }

    /**
     * @return metadata, decimals to express the common denomination
     *   of the currency provided by this oracle
     * @notice Defined by the RCN RateOracle interface
     */
    function decimals() external override view returns (uint256) {
        return idecimals;
    }

    /**
     * @return metadata, token address of the currency provided by this oracle
     * @notice Defined by the RCN RateOracle interface
     */
    function token() external override view returns (address) {
        return itoken;
    }

    /**
     * @return metadata, bytes32 code of the currency provided by this oracle
     * @notice Defined by the RCN RateOracle interface
     */
    function currency() external override view returns (bytes32) {
        return icurrency;
    }

    /**
     * @return metadata, human readable name of the entity maintainer of this oracle
     * @notice Defined by the RCN RateOracle interface
     */
    function maintainer() external override view returns (string memory) {
        return imaintainer;
    }

    /**
     * @dev Returns the URL required to retrieve the auxiliary data
     *   as specified by the RateOracle spec, no auxiliary data is required
     *   so it returns an empty string.
     * @return An empty string, because the auxiliary data is not required
     * @notice Defined by the RCN RateOracle interface
     */
    function url() external override view returns (string memory) {
        return "";
    }

    /**
     * @dev Updates the medatada of the oracle
     * @param _name Name of the oracle currency
     * @param _decimals Decimals for the common representation of the currency
     * @param _maintainer Name of the maintainer entity of the Oracle
     * @param _token, token address of the currency provided by this oracle
     * @param _path, path to get the currency rate
     */
    function setMetadata(
        string calldata _name,
        uint256 _decimals,
        string calldata _maintainer,
        address _token,
        bytes32[] calldata _path
    ) external onlyOwner {
        iname = _name;
        idecimals = _decimals;
        imaintainer = _maintainer;
        itoken = _token;
        path = _path;
    }

    /**
     * @dev Updates the Oracle contract, all subsequent calls to `readSample` will be forwareded to `_upgrade`
     * @param _upgrade Contract address of the new updated oracle
     * @notice If the `upgrade` address is set to the address `0` the Oracle is considered not upgraded
     */
    function setUpgrade(RateOracle _upgrade) external onlyOwner {
        upgrade = _upgrade;
    }

    /**
     * @dev Reads the rate provided by the Oracle
     *   this being the median of the last rate provided by each signer
     * @param _oracleData Oracle auxiliar data defined in the RCN Oracle spec
     *   not used for this oracle, but forwarded in case of upgrade.
     * @return _tokens _equivalent `_equivalent` is the median of the values provided by the signer
     *   `_tokens` are equivalent to `_equivalent` in the currency of the Oracle
     */
    function readSample(bytes memory _oracleData) public override view returns (uint256 _tokens, uint256 _equivalent) {
        // Check if paused
        // require(!paused && !pausedProvider.isPaused(), "contract paused");

        // Check if Oracle contract has been upgraded
        RateOracle _upgrade = upgrade;
        if (address(_upgrade) != address(0)) {
            return _upgrade.readSample(_oracleData);
        }

        // Tokens is always base
        _tokens = ibase;
        _equivalent = oracleAdapter.getRate(path);
    }

    /**
     * @dev Reads the rate provided by the Oracle
     *   this being the median of the last rate provided by each signer
     * @return _tokens _equivalent `_equivalent` is the median of the values provided by the signer
     *   `_tokens` are equivalent to `_equivalent` in the currency of the Oracle
     * @notice This Oracle accepts reading the sample without auxiliary data
     */
    function readSample() external view returns (uint256 _tokens, uint256 _equivalent) {
        (_tokens, _equivalent) = readSample(new bytes(0));
    }
}
