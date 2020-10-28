const ChainlinkAdapterV3 = artifacts.require('ChainlinkAdapterV3');
const FakeAggregatorV3 = artifacts.require('FakeAggregatorV3');
const OracleFactory = artifacts.require('OracleFactory');
const MultiSourceOracle = artifacts.require('MultiSourceOracle');

const {
    bn,
    toEvents,
    tryCatchRevert,
    expect,
    address0x,
} = require('../Helper.js');
const { assert } = require('chai');

contract('chainLink Diaspore oracle contract integration', function (accounts) {
    const owner = accounts[0];

    let chainlinkAdapter;
    let aggregator1;
    let aggregator2;
    let aggregator3;
    let aggregator4;
    let aggregator5;
    let aggregator6;
    let oracleFactory, oracleFactoryUSDC;

    async function setAggregator (symbolA, symbolB, aggregator) {
        const currencyA = await chainlinkAdapter.symbolToBytes32(symbolA);
        const currencyB = await chainlinkAdapter.symbolToBytes32(symbolB);
        await chainlinkAdapter.setAggregator(currencyA, currencyB, aggregator);
    };

    async function symbolToBytes32 (symbol) {
        const currency = await chainlinkAdapter.symbolToBytes32(symbol);
        return currency;
    }

    before('Deploy contracts', async function () {
        chainlinkAdapter = await ChainlinkAdapterV3.new();

        aggregator1 = await FakeAggregatorV3.new('RCN', 'BTC', '18', 'RCN/BTC', '1');
        await aggregator1.setLatestAnswer(bn('5770000000000'));
        await setAggregator('RCN', 'BTC', aggregator1.address);

        aggregator2 = await FakeAggregatorV3.new('BTC', 'ARS', '18', 'BTC/ARS', '1');
        await aggregator2.setLatestAnswer(bn('1538461538000000000000000'));
        await setAggregator('BTC', 'ARS', aggregator2.address);

        aggregator3 = await FakeAggregatorV3.new('USDC', 'ETH', '18', 'USDC/ETH', '1');
        await aggregator3.setLatestAnswer(bn('2438295000000000'));
        await setAggregator('USDC', 'ETH', aggregator3.address);

        aggregator4 = await FakeAggregatorV3.new('ETH', 'USD', '8', 'ETH/USD', '1');
        await aggregator4.setLatestAnswer(bn('40459747073'));
        await setAggregator('ETH', 'USD', aggregator4.address);

        aggregator5 = await FakeAggregatorV3.new('GBP', 'USD', '8', 'GBP/USD', '1');
        await aggregator5.setLatestAnswer(bn('131019000'));
        await setAggregator('GBP', 'USD', aggregator5.address);

        aggregator6 = await FakeAggregatorV3.new('BTC', 'ETH', '18', 'BTC/ETH', '1');
        await aggregator6.setLatestAnswer(bn('29489572978791538000'));
        await setAggregator('BTC', 'ETH', aggregator6.address);

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
            const factoryDecimals = await oracleFactory.baseDecimals();
            const decCurrency = await chainlinkAdapter.getDecimals(currencyC, currencyD);
            expect(tokens).to.eq.BN(factoryDecimals.mul(bn(10 ** decCurrency)));
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
            const factoryDecimals = await oracleFactory.baseDecimals();
            const decCurrency = await chainlinkAdapter.getDecimals(currencyB, currencyC);
            expect(tokens).to.eq.BN(factoryDecimals.mul(bn(10 ** decCurrency)));
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
            const factoryDecimals = await oracleFactoryUSDC.baseDecimals();
            const decCurrency = await chainlinkAdapter.getDecimals(currencyC, currencyD);
            expect(tokens).to.eq.BN(factoryDecimals.mul(bn(10 ** decCurrency)));
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
            const factoryDecimals = await oracleFactoryUSDC.baseDecimals();
            const decCurrency = await chainlinkAdapter.getDecimals(currencyC, currencyD);
            expect(tokens).to.eq.BN(factoryDecimals.mul(bn(10 ** decCurrency)));
        });
        it('Test Oracle Factory for USDC , set path [USDC,ETH,USD,GBP] ', async function () {
            const currencyA = await symbolToBytes32('USDC');
            const currencyB = await symbolToBytes32('ETH');
            const currencyC = await symbolToBytes32('USD');
            const currencyD = await symbolToBytes32('GBP');

            const NewOracle = await toEvents(
                oracleFactoryUSDC.newOracle(
                    chainlinkAdapter.address,
                    'GBP',
                    'Libra esterlina',
                    '8',
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
            const factoryDecimals = await oracleFactoryUSDC.baseDecimals();
            const decCurrency = await chainlinkAdapter.getDecimals(currencyC, currencyD);
            expect(tokens).to.eq.BN(factoryDecimals.mul(bn(10 ** decCurrency)));
        });
    });

    describe('Test pausable ', async function () {
        it('Test pause ecosystem ', async function () {
            // Pause ecosystem
            assert.equal(await oracleFactory.paused(), false);
            await oracleFactory.pause({ from: owner });
            assert.equal(await oracleFactory.paused(), true);

            await tryCatchRevert(
                () => oracleFactory.start(
                    { from: accounts[1] }
                ),
                'Ownable: caller is not the owner'
            );

            const usdcOracle = await oracleFactory.symbolToOracle('USDC');
            const oracleInstance = await MultiSourceOracle.at(usdcOracle);

            await tryCatchRevert(
                () => oracleInstance.readSample(
                    [],
                    { from: owner }
                ),
                'contract paused'
            );

            // start ecosystem
            await oracleFactory.start({ from: owner });
            assert.equal(await oracleFactory.paused(), false);
        });
        it('Test pause oracle ', async function () {
            const usdcOracle = await oracleFactory.symbolToOracle('USDC');
            const oracleInstance = await MultiSourceOracle.at(usdcOracle);
            assert.equal(await oracleInstance.paused(), false);

            await tryCatchRevert(
                () => oracleFactory.pauseOracle(
                    usdcOracle,
                    { from: accounts[1] }
                ),
                'not authorized to pause'
            );

            await oracleFactory.pauseOracle(usdcOracle);
            assert.equal(await oracleInstance.paused(), true);

            await tryCatchRevert(
                () => oracleInstance.readSample(
                    [],
                    { from: owner }
                ),
                'contract paused'
            );

            await oracleFactory.startOracle(usdcOracle);
            assert.equal(await oracleInstance.paused(), false);
        });
    });
    describe('Test lastesTimestamp()', function () {
        it('get latestTimestamp ', async function () {
            const usdcOracle = await oracleFactory.symbolToOracle('USDC');
            const oracleInstance = await MultiSourceOracle.at(usdcOracle);

            const lastTimestampA = '1598500000';
            const lastTimestampB = '1598200000';
            const lastTimestampC = '1598800000';
            await aggregator1.setLastTimestamp(bn(lastTimestampA)); // RCN/BTC
            await aggregator6.setLastTimestamp(bn(lastTimestampB)); // BTC/ETH
            await aggregator3.setLastTimestamp(bn(lastTimestampC)); // USDC/ETH

            const timestamp = await oracleInstance.latestTimestamp();
            expect(timestamp).to.eq.BN(lastTimestampB);
        });
    });
});
