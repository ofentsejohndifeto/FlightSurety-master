pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

//import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    //using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract
    ABIFlightSuretyData private flightSuretyData;

    address[] private registeredOracles;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;        
        address airline;
    }

    mapping(bytes32 => Flight) private flights;

    mapping(bytes32 => bytes32) private flightKeys; // maps keys to look up fllight
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (
                                    address dataContractAddress
                                ) 
                                public 
    {
        contractOwner = msg.sender;
        flightSuretyData = ABIFlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
                            public 
                            view
                            returns(bool) 
    {
        return flightSuretyData.isOperational(); // Modify to call data contract's status
    }

    function isPassengerRegistered(
        address _passenger
    ) public view returns (bool) {
        return flightSuretyData.isPassengerRegistered(_passenger);
    }

    /**
     * @dev Is Flight registered  check from the data contract
     */
    function isFlghtRegistered(
        bytes32 _flightKey
    ) external view returns (bool) {
        return flights[_flightKey].isRegistered;
    }

    /**
     * @dev function so that we can check if a flight is delayed from the data contract
     */
    function isFlightDelayed(bytes32 _flightKey) external view returns (bool) {
        if (flights[_flightKey].statusCode == 20) {
            return true;
        }
        return false;
    }

    /**
     * @dev function so that we can retrieve the flightKey for a given lookupKey
     * from the client dapp
     */
    function getFlightKey(bytes32 _lookupKey) public view returns (bytes32) {
        return flightKeys[_lookupKey];
    }

    /**
     * @dev function called by the server to get the oracle responses.
     */
    function getOracleResponse(
        uint8 index,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) public view returns (address[] memory) {
        bytes32 key = keccak256(abi.encodePacked(index, flight, timestamp));
        return oracleResponses[key].responses[statusCode];
    }

    /**
     * Getter function to retrieve the list of registered oracle addresses
     */
    function getRegisteredOracles() public view returns (address[] memory) {
        return registeredOracles;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

  /**
     * @dev Registers a passenger to the passengers mapping in Data contract.
     *
     */
    function registerPassenger(address _passengerAddress) public {
        require(
            flightSuretyData.isPassengerRegistered(_passengerAddress) == false,
            "Passenger is already registered"
        );
        flightSuretyData.registerPassenger(_passengerAddress);
    }

   /**
    * @dev Add an airline to reigstration queue to be voted on
    *
    */   
    function registerAirline
                            (   
                                address airline
                            )
                            external
                            view
                            returns(bool success, uint256 votes)
    {
        (success, votes) = flightSuretyData.registerAirline(
            airline,
            msg.sender
        );
        return (success, 0);
    }


   /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string _flight,
        uint256 _timestamp
    ) external {
        require(
            flightSuretyData.isAirlineRegistered(msg.sender),
            "Caller is not a registered airline"
        );
        bytes32 flightKey = getFlightKey(msg.sender, _flight, _timestamp);
        bytes32 lookupKey = keccak256(abi.encodePacked(msg.sender, _flight)); // msg.sender owns flight being reigstered
        flightKeys[lookupKey] = flightKey;
        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: 0,
            updatedTimestamp: _timestamp,
            airline: msg.sender
        });
    }

    /**
     * @dev Function called by the passenger to buy insurance for a flight
     */
    function buy(bytes32 _flightKey) external payable {
        require(
            flightSuretyData.isPassenger(msg.sender),
            "You are not a passenger"
        );
        flightSuretyData.buy.value(msg.value)(_flightKey, msg.sender);

    }

    /**
     * @dev Function called by the passenger to have an insurance credit paid to him
     */
    function pay(bytes32 _flightKey) external {
        require(
            flightSuretyData.isPassenger(msg.sender),
            "You are not a passenger"
        );
        flightSuretyData.pay(_flightKey, msg.sender);
    }

    /**
     * @dev Function called by the airline to submit their initial funding for the contract
     */
    function fund() external payable {
    require(msg.value >= 10 ether, "You should fund at least 10 ether");

    // Transfer funds to the Data contract
    flightSuretyData.fund.value(msg.value)(msg.sender);
}

    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus(
        address _airline,
        string memory _flight,
        uint256 _timestamp,
        uint8 _statusCode
    ) internal {
        if (_statusCode == 20) {
            bytes32 lookupKey = keccak256(abi.encodePacked(_airline, _flight));
            bytes32 flightKey = flightKeys[lookupKey];
            require(
                flights[flightKey].isRegistered,
                "Flight is not registered"
            );
            flights[flightKey].statusCode = _statusCode;
            flights[flightKey].updatedTimestamp = _timestamp;

            flightSuretyData.creditInsurers(flightKey, _airline, _flight);
        }
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address _airline,
        string _flight,
        uint256 _timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, _airline, _flight, _timestamp)
        );
        oracleResponses[key].requester = msg.sender;
        oracleResponses[key].isOpen = true;

        emit OracleRequest(index, _airline, _flight, _timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        address oracleAddress;
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() external payable {
        // Skip registration if oracle is already registered
        if (oracles[msg.sender].isRegistered == true) {
            return;
        }
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            oracleAddress: msg.sender,
            isRegistered: true,
            indexes: indexes
        });

        // Add the oracle address to the list of registered oracles
        registeredOracles.push(msg.sender);
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status 
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (                       
                                address account         
                            )
                            internal
                            returns(uint8[3] memory)
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce >= 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}   

// Interface with data contract
interface ABIFlightSuretyData {
    function setAppContract
                            (
                                address _flightSuretyApp
                            ) external;

    function registerPassenger
                                (
                                    address _passengerAddress
                                ) external;

    function registerAirline(
                                address airline,
                                address caller
                            ) external returns (bool, uint256);

    function buy(
                    bytes32 _flightKey, 
                    address _caller
                ) external payable;

    function pay(
                    bytes32 _flightKey, 
                    address _caller
                ) external;

    function isOperational
                            (
                            ) external view returns (bool);

    function isPassengerRegistered(
                                    address _passenger
                                  ) external view returns (bool);

    function isAirlineRegistered(
                                    address airline
                                ) external view returns (bool);

    function isPassenger(
                            address passenger
                        ) external view returns (bool);

    function creditInsurers(
                                bytes32 _flightKey,
                                address _airline,
                                string _flight
                           ) external;

    function fund(
                    address _caller
                 ) external payable;
}