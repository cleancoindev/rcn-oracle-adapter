const ChainlinkAdapter = artifacts.require('ChainlinkAdapter');
const FakeAggregator = artifacts.require('FakeAggregator');
const OracleFactory = artifacts.require('OracleFactory');
const MultiSourceOracle = artifacts.require('MultiSourceOracle');

const {
    bn,
    tryCatchRevert,
    toEvents,
    expect,
    address0x,
} = require('../Helper.js');
const { assert } = require('chai');

contract('chainLinkAdapter Contract', function (accounts) {
    const owner = accounts[0];

    let chainlinkAdapter;
    let aggregator1;
    let aggregator2;
    let aggregator3;
    let aggregator4;
    let aggregator5;
    let aggregator6;
    let oracleFactory, oracleFactoryUSDC;

    async function setAggregator (symbolA, symbolB, aggregator, decimalsA, decimalsB) {
        const currencyA = await chainlinkAdapter.symbolToBytes32(symbolA);
        const currencyB = await chainlinkAdapter.symbolToBytes32(symbolB);
        await chainlinkAdapter.setAggregator(currencyA, currencyB, aggregator, decimalsA, decimalsB);
    };

    async function symbolToBytes32 (symbol) {
        const currency = await chainlinkAdapter.symbolToBytes32(symbol);
        return currency;
    }

    before('Deploy contracts', async function () {
        chainlinkAdapter = await ChainlinkAdapter.new();

        aggregator1 = await FakeAggregator.new('RCN', 'BTC');
        await aggregator1.setLatestAnswer(bn('5770000000000'));
        await setAggregator('RCN', 'BTC', aggregator1.address, '18', '18');

        aggregator2 = await FakeAggregator.new('BTC', 'ARS');
        await aggregator2.setLatestAnswer(bn('1538461538000000000000000'));
        await setAggregator('BTC', 'ARS', aggregator2.address, '18', '18');

        aggregator3 = await FakeAggregator.new('USDC', 'ETH');
        await aggregator3.setLatestAnswer(bn('2438295000000000'));
        await setAggregator('USDC', 'ETH', aggregator3.address, '18', '18');

        aggregator4 = await FakeAggregator.new('ETH', 'USD');
        await aggregator4.setLatestAnswer(bn('4094400000'));
        await setAggregator('ETH', 'USD', aggregator4.address, '18', '8');

        aggregator5 = await FakeAggregator.new('GBP', 'USD');
        await aggregator5.setLatestAnswer(bn('131019000'));
        await setAggregator('GBP', 'USD', aggregator5.address, '18', '8');

        aggregator6 = await FakeAggregator.new('BTC', 'ETH');
        await aggregator6.setLatestAnswer(bn('29489572978791538000'));
        await setAggregator('BTC', 'ETH', aggregator6.address, '18', '18');

        // Create Oracle Factory
        oracleFactory = await OracleFactory.new('RCN', '18');
        oracleFactoryUSDC = await OracleFactory.new('USDC', '6');
    });

    describe('Test oracle Factory integration ', async function () {
        it('Test Oracle Factory for RCN , set path [RCN,BTC,ETH,USDC] ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const currencyC = await symbolToBytes32('ETH');
            const currencyD = await symbolToBytes32('USDC');

            const NewOracle = await toEvents(
                oracleFactory.newOracle(
                    chainlinkAdapter.address,
                    'USDC',
                    'Token USDC',
                    '6',
                    address0x,
                    'RCN team',
                    [currencyA, currencyB, currencyC, currencyD],
                    { from: owner }
                ),
                'NewOracle');

            const combRate = await chainlinkAdapter.getRate([currencyA, currencyB, currencyC, currencyD]);

            const oracleInstance = await MultiSourceOracle.at(NewOracle._oracle);
            const readSample = await oracleInstance.readSample.call([]);
            const tokens = readSample._tokens;
            const equivalent = readSample._equivalent;
            const decimals = await oracleInstance.decimals();

            expect(equivalent).to.eq.BN(combRate.mul(bn(10 ** decimals)));
            const decimalsAdded = await chainlinkAdapter.getAddedDecimals(currencyD);
            const factoryDecimals = await oracleFactory.baseDecimals();
            expect(tokens).to.eq.BN(factoryDecimals.mul(decimalsAdded));

        });
        it('Test Oracle Factory for RCN , set path [RCN,BTC,ARS] ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const currencyC = await symbolToBytes32('ARS');

            const NewOracle = await toEvents(
                oracleFactory.newOracle(
                    chainlinkAdapter.address,
                    'ARS',
                    'Argentine Peso',
                    '2',
                    address0x,
                    'RCN team',
                    [currencyA, currencyB, currencyC],
                    { from: owner }
                ),
                'NewOracle');
            const combinedRate = await chainlinkAdapter.getRate([currencyA, currencyB, currencyC]);

            const oracleInstance = await MultiSourceOracle.at(NewOracle._oracle);
            const readSample = await oracleInstance.readSample.call([]);
            const tokens = readSample._tokens;
            const equivalent = readSample._equivalent;
            const decimals = await oracleInstance.decimals();

            expect(equivalent).to.eq.BN(combinedRate.mul(bn(10 ** decimals)));
            const decimalsAdded = await chainlinkAdapter.getAddedDecimals(currencyC);
            const factoryDecimals = await oracleFactory.baseDecimals();
            expect(tokens).to.eq.BN(factoryDecimals.mul(decimalsAdded));
        });
        it('Test Oracle Factory for USDC , set path [USDC,ETH,BTC,RCN] ', async function () {
            const currencyA = await symbolToBytes32('USDC');
            const currencyB = await symbolToBytes32('ETH');
            const currencyC = await symbolToBytes32('BTC');
            const currencyD = await symbolToBytes32('RCN');

            const NewOracle = await toEvents(
                oracleFactoryUSDC.newOracle(
                    chainlinkAdapter.address,
                    'RCN',
                    'Token RCN',
                    '18',
                    address0x,
                    'RCN team',
                    [currencyA, currencyB, currencyC, currencyD],
                    { from: owner }
                ),
                'NewOracle');

            const combRate = await chainlinkAdapter.getRate([currencyA, currencyB, currencyC, currencyD]);

            const oracleInstance = await MultiSourceOracle.at(NewOracle._oracle);
            const readSample = await oracleInstance.readSample.call([]);
            const tokens = readSample._tokens;
            const equivalent = readSample._equivalent;
            const decimals = await oracleInstance.decimals();

            expect(equivalent).to.eq.BN(combRate.mul(bn(10 ** decimals)));
            const decimalsAdded = await chainlinkAdapter.getAddedDecimals(currencyD);
            const factoryDecimals = await oracleFactoryUSDC.baseDecimals();
            expect(tokens).to.eq.BN(factoryDecimals.mul(decimalsAdded));
        });
        it('Test Oracle Factory for USDC , set path [USDC,ETH,BTC,ARS] ', async function () {
            const currencyA = await symbolToBytes32('USDC');
            const currencyB = await symbolToBytes32('ETH');
            const currencyC = await symbolToBytes32('BTC');
            const currencyD = await symbolToBytes32('ARS');

            const NewOracle = await toEvents(
                oracleFactoryUSDC.newOracle(
                    chainlinkAdapter.address,
                    'ARS',
                    'Argentine Peso',
                    '2',
                    address0x,
                    'RCN team',
                    [currencyA, currencyB, currencyC, currencyD],
                    { from: owner }
                ),
                'NewOracle');

            const combRate = await chainlinkAdapter.getRate([currencyA, currencyB, currencyC, currencyD]);

            const oracleInstance = await MultiSourceOracle.at(NewOracle._oracle);
            const readSample = await oracleInstance.readSample.call([]);
            const tokens = readSample._tokens;
            const equivalent = readSample._equivalent;
            const decimals = await oracleInstance.decimals();

            expect(equivalent).to.eq.BN(combRate.mul(bn(10 ** decimals)));
            const decimalsAdded = await chainlinkAdapter.getAddedDecimals(currencyD);
            const factoryDecimals = await oracleFactoryUSDC.baseDecimals();
            expect(tokens).to.eq.BN(factoryDecimals.mul(decimalsAdded));
        });
    });
});
