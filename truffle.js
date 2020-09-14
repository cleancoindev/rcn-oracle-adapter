module.exports = {
    networks: {
        development: {
            host: 'localhost',
            port: 8545,
            network_id: '*', // eslint-disable-line camelcase
            gas: 6721975,
        },
    },
    mocha: {
        reporter: 'eth-gas-reporter',
    },
    compilers: {
        solc: {
            version: '0.6.6', // Fetch exact version from solc-bin (default: truffle's version)
            // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200,
                },
                evmVersion: 'istanbul',
            },
        },
    },
    plugins: ['solidity-coverage'],
};
