var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
        // Initialize the contract configuration
        config = await Test.Config(accounts);
        // Authorize the app contract to call functions in the data contract
        // await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });

    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/

    it(`(multiparty) has correct initial isOperational() value`, async function () {
        // Check if the initial operational status of the contract is true
        let status = await config.flightSuretyApp.isOperational.call();
        assert.equal(status, true, "Incorrect initial operating status value");
    });

    it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
        // Ensure that only the contract owner can change the operational status
        let accessDenied = false;
        try {
            // Attempt to change operational status from a non-owner account
            await config.flightSuretyData.setOperatingStatus(false, {from: config.testAddresses[2]});
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
    });

    it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
        // Ensure that the contract owner can change the operational status
        let accessDenied = false;
        try {
            // Change the operational status from the contract owner account
            await config.flightSuretyData.setOperatingStatus(false, {from: config.firstAirline});
        } catch (e) {
            accessDenied = true;
        }
        assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

        // Reset the operational status to true for other tests
        await config.flightSuretyData.setOperatingStatus(true, {from: config.firstAirline});
    });

    it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
        // Change operational status to false
        await config.flightSuretyData.setOperatingStatus(false, {from: config.firstAirline});

        let reverted = false;
        try {
            // Attempt to call a function that requires operational status to be true
            await config.flightSuretyApp.activateAirline();
        } catch (e) {
            reverted = true;
        }
        assert.equal(reverted, true, "Access not blocked for requireIsOperational");

        // Reset the operational status to true for other tests
        await config.flightSuretyData.setOperatingStatus(true, {from: config.firstAirline});
    });

    it('(airline) can fund first airline', async () => {
        // Check if the first airline is not activated initially
        let result1 = await config.flightSuretyApp.isAirlineActivated.call(config.firstAirline);
        assert.equal(result1, false, "Airline is not activated before funding");

        // Fund the first airline
        await config.flightSuretyApp.activateAirline.sendTransaction(config.firstAirline, {
            from: config.firstAirline,
            value: config.weiMultiple * 10
        });

        // Check if the first airline is activated after funding
        let result2 = await config.flightSuretyApp.isAirlineActivated.call(config.firstAirline);
        assert.equal(result2, true, "Airline should be able to activate if it has provided funding");
    });

    it('(airline) can register 3 new airlines', async () => {
        // Check if the new airlines are not registered initially
        let result1 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[1]);
        assert.equal(result1, false, "Unable to register Airline 1");

        let result2 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[2]);
        assert.equal(result2, false, "Unable to register Airline 2");

        let result3 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[3]);
        assert.equal(result3, false, "Unable to register Airline 3");

        // Register 3 new airlines
        await config.flightSuretyApp.registerAirline(config.testAddresses[1], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(config.testAddresses[2], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(config.testAddresses[3], {from: config.firstAirline});

        // Check if the new airlines are registered
        let result4 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[1]);
        assert.equal(result4, true, "Unable to register Airline 1");

        let result5 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[2]);
        assert.equal(result5, true, "Unable to register Airline 2");

        let result6 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[3]);
        assert.equal(result6, true, "Unable to register Airline 3");
    });

    it('(airline) can fund the 3 new airlines', async () => {
        // Check if the new airlines are not activated initially
        let result1 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[1]);
        assert.equal(result1, false, "Unable to fund Airline 1");

        let result2 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[2]);
        assert.equal(result2, false, "Unable to fund Airline 2");

        let result3 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[3]);
        assert.equal(result3, false, "Unable to fund Airline 3");

        // Fund the 3 new airlines
        await config.flightSuretyApp.activateAirline(config.testAddresses[1], {
            from: config.firstAirline,
            value: config.weiMultiple * 10
        });
        await config.flightSuretyApp.activateAirline(config.testAddresses[2], {
            from: config.firstAirline,
            value: config.weiMultiple * 10
        });
        await config.flightSuretyApp.activateAirline(config.testAddresses[3], {
            from: config.firstAirline,
            value: config.weiMultiple * 10
        });

        // Check if the new airlines are activated after funding
        let result4 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[1]);
        assert.equal(result4, true, "Unable to fund Airline 1");

        let result5 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[2]);
        assert.equal(result5, true, "Unable to fund Airline 2");

        let result6 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[3]);
        assert.equal(result6, true, "Unable to fund Airline 3");
    });

    it('(airline) can register fourth new airline that requires multi-party consensus of 50% of registered airlines', async () => {
        // Check if the fourth new airline is not registered initially
        let result1 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[4]);
        assert.equal(result1, false, "Unable to register Airline");

        // Register the fourth new airline with multi-party consensus
        await config.flightSuretyApp.registerAirline(config.testAddresses[4], {from: config.firstAirline});
        await config.flightSuretyApp.registerAirline(config.testAddresses[4], {from: config.testAddresses[1]});

        // Check if the fourth new airline is registered
        let result2 = await config.flightSuretyApp.isAirlineRegistered.call(config.testAddresses[4]);
        assert.equal(result2, true, "Unable to register Airline");
    });

    it('(airline) can fund fourth new airline', async () => {
        // Check if the fourth new airline is not activated initially
        let result1 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[4]);
        assert.equal(result1, false, "Unable to fund Airline");

        // Fund the fourth new airline
        await config.flightSuretyApp.activateAirline(config.testAddresses[4], {
            from: config.firstAirline,
            value: config.weiMultiple * 10
        });

        // Check if the fourth new airline is activated after funding
        let result4 = await config.flightSuretyApp.isAirlineActivated.call(config.testAddresses[4]);
        assert.equal(result4, true, "Unable to fund Airline");
    });

    it(`(passenger) can buy insurance for a flight`, async function () {
        let flightName = "Bangalore to Jaipur";
        let timestamp = Math.floor(Date.now() / 1000);

        let isInsurancePurchased = true;

        try {
            // Buy insurance for a flight
            await config.flightSuretyApp.buyInsurance(config.firstAirline, flightName, timestamp, config.testAddresses[5], {
                from: config.firstAirline,
                value: config.weiMultiple
            });
        } catch (e) {
            isInsurancePurchased = false;
        }

        assert.equal(isInsurancePurchased, true, "Unable to purchase insurance");
    });
});
