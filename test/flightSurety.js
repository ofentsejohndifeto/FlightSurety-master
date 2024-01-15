var Test = require('../config/testConfig.js');

contract('Flight Surety Tests', async (accounts) => {

    var config;
    before('setup contract', async () => {
      config = await Test.Config(accounts);
      await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
    });
  
    /****************************************************************************************/
    /* Operations and Settings                                                              */
    /****************************************************************************************/
  
    it(`(multiparty) has correct initial isOperational() value`, async function () {
  
      // Get operating status
      let status = await config.flightSuretyData.isOperational.call();
      assert.equal(status, true, "Incorrect initial operating status value");
  
    });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) should be able to fund an airline and ensure it is properly recorded in FlightSuretyData', async () => {
    // ARRANGE
    let airlineToFund = accounts[2];
    let fundingAmount = web3.utils.toWei("10", "ether"); // Convert 10 ether to wei

    // ACT
    try {
        // Fund the airline using the App contract
        const result = await config.flightSuretyApp.fund({ from: airlineToFund, value: fundingAmount });

        //LOG statements before calling fund function
        console.log("Caller is authorized:", isAuthorizedCaller());
        
        // Check if the airline is properly funded in the Data contract
        let isAirlineFunded = await config.flightSuretyData.isAirlineFunded.call(airlineToFund);

        // Additional logging for debugging
        console.log("Is Airline Funded?", isAirlineFunded);

        // Get the events emitted during the transaction
        const events = result.logs;

        // Declare and Initialize a variable for event
        let eventEmitted = false;

        // Log all emitted events for debugging
        console.log("Events emitted during test:", events);

        // Check if the AccountFunded event was emitted
        events.forEach(event => {
            console.log("Event name:", event.event); // Log the event name for debugging
            if (event.event === 'AccountFunded') {
                // Add any additional conditions you need to check for the event
                eventEmitted = true;
            }
        });

        // Log the result for debugging
        console.log("Transaction result:", result);

        // Assert if the event was emitted
        assert.equal(eventEmitted, true, 'AccountFunded event should be emitted');

        // ASSERT
        assert.equal(isAirlineFunded, true, "Airline should be properly funded in FlightSuretyData");
    } catch (e) {
        // Log the caught error for debugging
        console.error("Caught error:", e.message);
        assert.fail("Unexpected error during funding");
    }
});


});
