pragma solidity ^0.4.25;

//import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyApp.sol";

contract FlightSuretyData {
    //using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // address used to deploy contract
    bool private operational = true; // Blocks all state changes in contract if false. Done if problems in execution of contract found
    ABIFlightSuretyApp private flightSuretyApp; // Address of flightSuretyApp contract.
    uint airlineCounter = 0; // Counter to keep amount of airlines registered
    uint public voteDuration = 1 hours; // Set the length of time to vote
    mapping(address => bool) private authorizedCallers; // Tracks who is authorized contract callers                            

    struct Passenger {
        address passengerAddress;
        uint256 credit;
        bool isPassengerRegistered;
    }
    mapping(address => Passenger) private passengers;

    struct Airline {
        address airlineAddress;
        bool isAirlineRegistered;
        bool hasFunded;
    }
    mapping(address => Airline) private airlines;

    struct Proposal {
        uint votes;
        uint timestamp;
        mapping(address => bool) voters;
    }
    mapping(bytes32 => Proposal) private proposals;

    // Mapping flightKey to the list of passengers who bought insurance for that flight
    mapping(bytes32 => address[]) private flightInsurers;

    // Mapping flightKey and passenger to the amount they they funded to be insured for that flight
    mapping(bytes32 => mapping(address => uint256))
        private flightInsuranceAmounts;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                )
    {
        contractOwner = msg.sender;
    }

    // events
    event ProposalCreated(bytes32 indexed proposalId);

    event ProposalPassed(bytes32 indexed proposalId);
    
    event ProposalExpired(bytes32 indexed proposalId);
    
    event InsuranceBought(
        bytes32 indexed flightKey,
        uint256 indexed insuranceAmount
    );

    event PaymentMade(bytes32 indexed flightKey, address indexed caller);
    
    event AccountFunded(address indexed caller);
    
    event PassengerRegistered(address indexed passengerAddress);
    
    event AirlineRegistered(address indexed airline);
    
    event InsurersCredited(
        bytes32 indexed flightKey,
        address indexed airline,
        string flight,
        address indexed passengerAddress,
        uint256 credit
    );
    
    
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
        require(operational, "Contract is currently not operational");
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

    /**
    * @dev Modifier insures ONLY flightSuretyApp contract can call function
    */
    modifier isAuthorized() {
        require(
            authorizedCallers[msg.sender] == true,
            "Caller is not authorised to call this contract"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
                            public 
                            view 
                            returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
                            (
                                bool mode
                            ) 
                            external
                            requireContractOwner 
    {
        operational = mode;
    }

    /**
     * @dev Sets address for the App contract once contract is deployed
     */
    function setAppContract(
        address _flightSuretyApp
    ) external requireContractOwner {
        flightSuretyApp = ABIFlightSuretyApp(_flightSuretyApp);
    }

    /**
     * @dev re-usable multi-party consensus voting function
     */
    function vote(
        bytes32 _proposalId,
        address _voter
    ) internal requireIsOperational returns (bool) {
        Proposal storage proposal = proposals[_proposalId];
        require(
            !proposal.voters[_voter],
            "Caller has already voted on this proposal"
        );
        proposal.voters[_voter] = true;
        proposal.votes++;

        if (proposal.votes >= airlineCounter / 2) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev check to see if passanger is registered from FlightSuretyApp contract
     */
    function isPassengerRegistered(
        address _passenger
    ) external view returns (bool) {
        return passengers[_passenger].isPassengerRegistered;
    }

    /**
     * @dev check to see if airline is actuall reigstered in flightSuretyApp contract
     */
    function isAirlineRegistered(
        address _airline
    ) external view returns (bool) {
        return airlines[_airline].isAirlineRegistered;
    }

    // check to see if passenger is registered but not to any particular flight
    function isPassenger(address _passenger) public view returns (bool) {
        if (passengers[_passenger].passengerAddress != address(0)) {
            return true;
        }
        return false;
    }

    /**
     * @dev function to add authorized callers of the contract
     */
    function authorizeCaller(address _caller) public requireContractOwner {
        authorizedCallers[_caller] = true;
    }

    /**
     * @dev internal function to add authorized callers of this contract.
     *      This can only be called from within the contract itself.
     */
    function internalAuthorizeCaller(address _caller) internal {
        authorizedCallers[_caller] = true;
    }

    /**
     * @dev function to remove an address from authorized callers list
     */
    function deauthorizeCaller(address _caller) public requireContractOwner {
        delete authorizedCallers[_caller];
    }

     /**
     * @dev function to check if the address calling the contract is authorized
     */
    function isAuthorizedCaller() public view returns (bool) {
        return authorizedCallers[msg.sender];
    }

     function registerFirstAirline(address _airline) internal {
        airlines[_airline] = Airline({
            airlineAddress: _airline,
            isAirlineRegistered: true,
            hasFunded: false
        });
        airlineCounter++;
        internalAuthorizeCaller(_airline); //authorizing airline to be able to authroize other airlines
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Add a passenger to the passengers mapping. This function is called by registerPassenger function in the App
     * contract, which in turn is called by the user in the client dapp.
     */
    function registerPassenger(
        address _passengerAddress
    ) external isAuthorized {
        passengers[_passengerAddress] = Passenger({
            passengerAddress: _passengerAddress,
            credit: 0,
            isPassengerRegistered: true
        });
        emit PassengerRegistered(_passengerAddress);
    }

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline(
        address _airline,
        address _caller
    )
        public
        requireIsOperational
        isAuthorized
        returns (bool success, uint256 votes)
    {
        require(
            airlines[_airline].airlineAddress == address(0),
            "Airline already exists"
        );
        require(
            airlines[_caller].hasFunded == true,
            "Caller has not funded account"
        );
        if (airlineCounter <= 4) {
            airlines[_airline] = Airline({
                airlineAddress: _airline,
                isAirlineRegistered: true,
                hasFunded: true
            });
            airlineCounter++;
            internalAuthorizeCaller(_airline);
            success = true;
            votes = 0; // No votes required if there are less than or equal to 4 airlines
            emit AirlineRegistered(_airline);
            return (success, votes);
        } else {
            require(
                airlines[_caller].isAirlineRegistered == true,
                "Caller is not an existing airline"
            );
            bytes32 proposalId = keccak256(
                abi.encodePacked("registerAirline", _airline)
            );
            Proposal storage proposal = proposals[proposalId];

            // Check if the proposal has expired
            if (
                proposal.timestamp != 0 &&
                (block.timestamp - proposal.timestamp) > voteDuration
            ) {
                emit ProposalExpired(proposalId);
                success = false;
                votes = proposal.votes;
                return (success, votes);
            }

            // If the proposal doesn't exist, create it
            if (proposal.timestamp == 0) {
                proposal.timestamp = block.timestamp;
                emit ProposalCreated(proposalId);
            }

            // Now we simply record the vote without checking for consensus here
            vote(proposalId, msg.sender);
            votes = proposal.votes;

            // Instead, we check for consensus here
            if (votes >= airlineCounter / 2) {
                airlines[_airline] = Airline({
                    airlineAddress: _airline,
                    isAirlineRegistered: true,
                    hasFunded: true
                });
                airlineCounter++;
                emit ProposalPassed(proposalId);
                internalAuthorizeCaller(_airline);
                success = true;
                emit AirlineRegistered(_airline);
                return (success, votes);
            } else {
                success = false; // Not enough votes yet
                return (success, votes);
            }
        }
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(
        bytes32 _flightKey,
        address _caller
    ) external payable isAuthorized {
        require(
            flightSuretyApp.isFlightRegistered(_flightKey),
            "Flight not found!"
        );
        require(
            flightInsuranceAmounts[_flightKey][_caller] == 0,
            "You already bought insurance."
        );
        require(msg.value <= 1 ether, "You can only insure up to 1 ether");
        flightInsurers[_flightKey].push(_caller);
        flightInsuranceAmounts[_flightKey][_caller] = msg.value;
        uint256 _insuranceAmount = flightInsuranceAmounts[_flightKey][_caller];
        emit InsuranceBought(_flightKey, _insuranceAmount);
    }

    /**
     *  @dev Credits payouts to insurees. Credit is equal to 1.5 x the insurance amount bought.
     */
    function creditInsurers(
        bytes32 _flightKey,
        address _airline,
        string _flight
    ) external isAuthorized {
        for (uint i = 0; i < flightInsurers[_flightKey].length; i++) {
            address passengerAddress = flightInsurers[_flightKey][i];
            uint256 credit = (flightInsuranceAmounts[_flightKey][
                passengerAddress
            ] * 3) / 2;
            passengers[passengerAddress].credit = credit;
            emit InsurersCredited(
                _flightKey,
                _airline,
                _flight,
                passengerAddress,
                credit
            );
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(bytes32 _flightKey, address _caller) external isAuthorized {
        require(
            passengers[_caller].passengerAddress != address(0),
            "You are not a passenger."
        );
        require(
            flightSuretyApp.isFlightRegistered(_flightKey),
            "Flight is not registered"
        );
        require(
            flightSuretyApp.isFlightDelayed(_flightKey),
            "This flight is not delayed"
        );
        uint totalCredit = passengers[_caller].credit;
        passengers[_caller].credit = 0;
        
        // Transfer funds to the caller
        _caller.transfer(totalCredit);

        emit PaymentMade(_flightKey, _caller);
    }

   /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund(address _caller) external payable isAuthorized {
        require(isAuthorizedCaller(), "Caller is not authorized");
        
        (isAuthorizedCaller(), "Caller is not authorized");
        require(msg.value >= 10 ether, "You should fund at least 10 ether");
        airlines[_caller].hasFunded = true;
        emit AccountFunded(_caller);
    }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }
 
}

interface ABIFlightSuretyApp {
    function isPassengerRegistered(address _passenger) external view returns (bool);

    function isFlightRegistered(bytes32 _flightKey) external view returns (bool);

    function isFlightDelayed(bytes32 _flightKey) external view returns (bool);
}

