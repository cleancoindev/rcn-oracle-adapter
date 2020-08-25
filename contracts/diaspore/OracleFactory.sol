pragma solidity ^0.6.6;

import "./MultiSourceOracle.sol";


contract OracleFactory is Ownable {
    mapping(string => address) public symbolToOracle;
    mapping(address => string) public oracleToSymbol;

    event NewOracle(
        address _oracleAdapter,
        string _symbol,
        address _oracle,
        string _name,
        uint256 _decimals,
        address _token,
        string _maintainer,
        bytes32[] _path
    );

    event Upgraded(
        address indexed _oracle,
        address _new
    );

    event UpdatedMetadata(
        address indexed _oracle,
        string _name,
        uint256 _decimals,
        string _maintainer,
        address _token,
        bytes32[] _path
    );

    string public baseToken;
    uint256 public baseDecimals;

    constructor(
        string memory _baseToken,
        uint256 _decimals
    ) public {
        baseToken = _baseToken;
        baseDecimals = 10 ** _decimals;
    }

    /**
     * @dev Creates a new Oracle contract for a given `_symbol`
     * @param _symbol metadata symbol for the currency of the oracle to create
     * @param _name metadata name for the currency of the oracle
     * @param _decimals metadata number of decimals to express the common denomination of the currency
     * @param _token metadata token address of the currency
     *   (if the currency has no token, it should be the address 0)
     * @param _maintainer metadata maintener human readable name
     * @notice Only one oracle by symbol can be created
     */
    function newOracle(
        IOracleAdapter _oracleAdapter,
        string calldata _symbol,
        string calldata _name,
        uint256 _decimals,
        address _token,
        string calldata _maintainer,
        bytes32[] calldata _path
    ) external onlyOwner {
        // Check for duplicated oracles
        require(symbolToOracle[_symbol] == address(0), "Oracle already exists");
        // Create oracle contract
        address oracle;
        {
        oracle = _createOracle(
            _oracleAdapter,
            _symbol,
            _name,
            _decimals,
            _token,
            _maintainer,
            _path
        );
        }
        // Sanity check new oracle
        assert(bytes(oracleToSymbol[address(oracle)]).length == 0);
        // Save Oracle in registry
        symbolToOracle[_symbol] = address(oracle);
        oracleToSymbol[address(oracle)] = _symbol;
        // Emit events
        _emitNewOracle(
            address(_oracleAdapter),
            _symbol,
            address(oracle),
            _name,
            _decimals,
            _token,
            _maintainer,
            _path
        );
    }

    /**
     * @dev Updates the Oracle contract, all subsequent calls to `readSample` will be forwareded to `_upgrade`
     * @param _oracle oracle address to be upgraded
     * @param _upgrade contract address of the new updated oracle
     * @notice Acts as a proxy of `_oracle.setUpgrade`
     */
    function setUpgrade(address _oracle, address _upgrade) external onlyOwner {
        MultiSourceOracle(_oracle).setUpgrade(RateOracle(_upgrade));
        emit Upgraded(_oracle, _upgrade);
    }

    /**
     * @dev Updates the medatada of the oracle
     * @param _oracle oracle address to update its metadata
     * @param _name Name of the oracle currency
     * @param _decimals Decimals for the common representation of the currency
     * @param _maintainer Name of the maintainer entity of the Oracle
     * @notice Acts as a proxy of `_oracle.setMetadata`
     */
    function setMetadata(
        address _oracle,
        string calldata _name,
        uint256 _decimals,
        string calldata _maintainer,
        address _token,
        bytes32[] calldata _path
    ) external onlyOwner {
        MultiSourceOracle(_oracle).setMetadata(
            _name,
            _decimals,
            _maintainer,
            _token,
            _path
        );

        emit UpdatedMetadata(
            _oracle,
            _name,
            _decimals,
            _maintainer,
            _token,
            _path
        );
    }

    function _createOracle(
        IOracleAdapter _oracleAdapter,
        string memory _symbol,
        string memory _name,
        uint256 _decimals,
        address _token,
        string memory _maintainer,
        bytes32[] memory _path
    ) private returns(address oracle)
    {
        oracle = address(
            new MultiSourceOracle(
            _oracleAdapter,
            baseToken,
            baseDecimals,
            _symbol,
            _name,
            _decimals,
            _token,
            _maintainer,
            _path
        ));
    }

    function _emitNewOracle(
        address _oracleAdapter,
        string memory _symbol,
        address oracle,
        string memory _name,
        uint256 _decimals,
        address _token,
        string memory _maintainer,
        bytes32[] memory _path
    ) private
    {
        emit NewOracle(
            _oracleAdapter,
            _symbol,
            oracle,
            _name,
            _decimals,
            _token,
            _maintainer,
            _path
        );
    }
}