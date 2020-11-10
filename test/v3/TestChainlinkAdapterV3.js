const ChainlinkAdapterV3 = artifacts.require('ChainlinkAdapterV3');
const FakeAggregatorV3 = artifacts.require('FakeAggregatorV3');

const {
    bn,
    tryCatchRevert,
    toEvents,
    expect,
    address0x,
} = require('../Helper.js');
const { assert } = require('chai');

function toDecimals (stringNumber, decimals) {
    return bn(stringNumber).mul(bn(10).pow(bn(decimals)));
}

contract('chainLinkAdapterV3 Contract', function (accounts) {
    const owner = accounts[0];

    let chainlinkAdapter;
    let aggregator1;
    let aggregator2;
    let aggregator3;
    let aggregator4;
    let aggregator5;

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
    });

    describe('Test getRate() ', async function () {
        it('getPairLastRate ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const newRate = '5780000000000';
            await aggregator1.setLatestAnswer(bn(newRate));
            const rate = await chainlinkAdapter.getPairLastRate(currencyA, currencyB);
            expect(rate.answer).to.eq.BN(newRate);
        });
        it('Get Rate from aggregator 1 using getRate() ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const newRate = '5770000000000';
            await aggregator1.setLatestAnswer(bn(newRate));
            const rate = await chainlinkAdapter.getRate([currencyA, currencyB]);
            expect(rate.combinedRate).to.eq.BN(newRate);
        });
        it('Get combined rate using getRate() path = 3 ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const currencyC = await symbolToBytes32('ARS');
            const rate = await chainlinkAdapter.getRate([currencyA, currencyB, currencyC]);

            const rateA = await chainlinkAdapter.getRate([currencyA, currencyB]);
            const rateB = await chainlinkAdapter.getRate([currencyB, currencyC]);
            const combRate = bn(rateA.combinedRate).mul(bn(rateB.combinedRate)).div(toDecimals('1', rateA.decimals));
            expect(rate.combinedRate).to.eq.BN(combRate);
        });
        it('Get reverse rate', async function () {
            const currencyA = await symbolToBytes32('BTC');
            const currencyB = await symbolToBytes32('RCN');
            assert(await chainlinkAdapter.aggregators(currencyA, currencyB), address0x);
            assert(await chainlinkAdapter.aggregators(currencyB, currencyA) !== address0x);
            const rate = await chainlinkAdapter.getRate([currencyA, currencyB]);

            const rateDirect = await chainlinkAdapter.getRate([currencyB, currencyA]);
            const reverseRate = bn(10).pow(rateDirect.decimals.mul(bn(2))).div(rateDirect.combinedRate);
            expect(rate.combinedRate).to.eq.BN(reverseRate);
        });

        it('Get combined rate using getRate() path = 4 and reverseRate', async function () {
            const currencyA = await symbolToBytes32('USDC');
            const currencyB = await symbolToBytes32('ETH');
            const currencyC = await symbolToBytes32('USD');
            const currencyD = await symbolToBytes32('GBP');
            const rate = await chainlinkAdapter.getRate([currencyA, currencyB, currencyC, currencyD]);

            const rateA = await chainlinkAdapter.getRate([currencyA, currencyB]);
            const rateB = await chainlinkAdapter.getRate([currencyB, currencyC]);
            const rateC = await chainlinkAdapter.getRate([currencyC, currencyD]);

            const combRate1 = bn(rateA.combinedRate).mul(bn(rateB.combinedRate)).div(toDecimals('1', rateA.decimals));
            const combRate2 = bn(combRate1).mul(bn(rateC.combinedRate)).div(toDecimals('1', rateB.decimals));
            expect(rate.combinedRate).to.eq.BN(combRate2);
        });
    });
    describe('Test reverts', async function () {
        it('Only owner can call set aggregator', async function () {
            const currencyA = await symbolToBytes32('symA');
            const currencyB = await symbolToBytes32('symB');
            const aggregator = accounts[1];
            await tryCatchRevert(
                () => chainlinkAdapter.setAggregator(
                    currencyA,
                    currencyB,
                    aggregator,
                    { from: accounts[1] }
                ),
                'Ownable: caller is not the owner'
            );
        });
        it('Aggregator 0x0 is not valid', async function () {
            const currencyA = await symbolToBytes32('symA');
            const currencyB = await symbolToBytes32('symB');
            const aggregator = address0x;
            await tryCatchRevert(
                () => chainlinkAdapter.setAggregator(
                    currencyA,
                    currencyB,
                    aggregator,
                    { from: owner }
                ),
                'ChainLinkAdapter/Aggregator 0x0 is not valid'
            );
        });
        it('ChainLinkAdapter/Aggregator not set, path not resolved', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('MANA');
            await tryCatchRevert(
                () => chainlinkAdapter.getRate(
                    [currencyA, currencyB],
                    { from: owner }
                ),
                'ChainLinkAdapter/Aggregator not set, path not resolved'
            );
        });
    });
    describe('Function setAggregator', function () {
        it('Should set a new Aggregator', async function () {
            const currencyA = await symbolToBytes32('symA');
            const currencyB = await symbolToBytes32('symB');
            const aggregator = aggregator1.address;
            const SetAggregator = await toEvents(
                chainlinkAdapter.setAggregator(
                    currencyA,
                    currencyB,
                    aggregator,
                    { from: owner }
                ),
                'SetAggregator'
            );
            assert.equal(SetAggregator._symbolA, currencyA);
            assert.equal(SetAggregator._symbolB, currencyB);
            assert.equal(SetAggregator._aggregator, aggregator);
        });
        it('Should revert if Aggregator exits', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const aggregator = aggregator1.address;
            await tryCatchRevert(
                () => chainlinkAdapter.setAggregator(
                    currencyA,
                    currencyB,
                    aggregator,
                    { from: owner }
                ),
                'ChainLinkAdapter/Aggregator is already set'
            );
        });
        it('Remove Aggregator', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const aggregator = await chainlinkAdapter.aggregators(currencyA, currencyB);
            const RemoveAggregator = await toEvents(
                chainlinkAdapter.removeAggregator(
                    currencyA,
                    currencyB,
                    { from: owner }
                ),
                'RemoveAggregator'
            );
            assert.equal(RemoveAggregator._symbolA, currencyA);
            assert.equal(RemoveAggregator._symbolB, currencyB);
            assert.equal(RemoveAggregator._aggregator, aggregator);
            const ra = await chainlinkAdapter.aggregators(currencyA, currencyB);
            assert.equal(address0x, ra);
            const SetAggregator = await toEvents(
                chainlinkAdapter.setAggregator(
                    currencyA,
                    currencyB,
                    aggregator1.address,
                    { from: owner }
                ),
                'SetAggregator'
            );
            assert.equal(SetAggregator._symbolA, currencyA);
            assert.equal(SetAggregator._symbolB, currencyB);
            assert.equal(SetAggregator._aggregator, aggregator);
        });
    });
    describe('Test lastesTimestamp()', function () {
        it('get latestTimestamp ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const lastTimestampA = '1598100000';
            await aggregator1.setLastTimestamp(bn(lastTimestampA));
            const timestamp = await chainlinkAdapter.latestTimestamp([currencyA, currencyB]);
            expect(timestamp).to.eq.BN(lastTimestampA);
        });
        it('GetlatestTimestamp() get min path = 3 ', async function () {
            const currencyA = await symbolToBytes32('RCN');
            const currencyB = await symbolToBytes32('BTC');
            const currencyC = await symbolToBytes32('ARS');
            const lastTimestampA = '1598200000';
            const lastTimestampB = '1598100000';
            await aggregator1.setLastTimestamp(bn(lastTimestampA));
            await aggregator2.setLastTimestamp(bn(lastTimestampB));

            const timestamp = await chainlinkAdapter.latestTimestamp([currencyA, currencyB, currencyC]);
            expect(timestamp).to.eq.BN(lastTimestampB);
        });
        it('GetlatestTimestamp() get min path = 4 ', async function () {
            const currencyA = await symbolToBytes32('USDC');
            const currencyB = await symbolToBytes32('ETH');
            const currencyC = await symbolToBytes32('USD');
            const currencyD = await symbolToBytes32('GBP');
            const lastTimestampA = '1598500000';
            const lastTimestampB = '1598200000';
            const lastTimestampC = '1598800000';

            await aggregator3.setLastTimestamp(bn(lastTimestampA));
            await aggregator4.setLastTimestamp(bn(lastTimestampB));
            await aggregator5.setLastTimestamp(bn(lastTimestampC));

            const timestamp = await chainlinkAdapter.latestTimestamp([currencyA, currencyB, currencyC, currencyD]);
            expect(timestamp).to.eq.BN(lastTimestampB);
        });
    });
});
