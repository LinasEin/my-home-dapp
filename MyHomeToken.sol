pragma solidity >=0.7.0 <0.9.0;
// SPDX-License-Identifier: MIT


contract MyHomesToken {
    address payable public owner;
    HousingPackage public hp;
    House[] public houseRegister;
    uint public totalHouses = 0;
    uint256 public totalShares = 100;
    uint256 public tokenPrice = 1;
    uint256 public shareLimit = 10;
    uint public totalShareHolders = 0;
    State private state;
    address[] public shareHolders;
    mapping(address => bool) public shareHolderRegistry;
    mapping (address => uint256) private balances;

    // Ballot
    BallotState private ballotState;
    address public ballotInitiator;
    string public ballotName;
    string public proposal;
    uint private resultCount = 0;
    uint public finalResult = 0;
    uint public totalVotes = 0;
    mapping(uint => Vote) private votes;


    constructor(string memory _name, string memory _description) payable {
        owner = payable(msg.sender);
        balances[msg.sender] = totalShares;
        hp.name = _name;
        hp.description = _description;
        hp.totalValue = 0;
        state = State.Created;
    }

    struct House {
        string registrationId;
        string physicalAddress;
        uint256 price;
    }

    struct HousingPackage {
        string name;
        string description;
        uint256 totalValue;
    }

    struct Vote {
        address shareHolderAddress;
        bool choice;
    }

    modifier onlyRegulator() {
		require(msg.sender == owner);
		_;
	}

    modifier inState(State _state) {
		require(state == _state);
		_;
	}

    modifier onlyBallotInitiator() {
		require(msg.sender == ballotInitiator);
		_;
	}

	modifier inBallotState(BallotState _state) {
		require(ballotState == _state);
		_;
	}

    event voteStarted();
    event voteEnded(uint finalResult);
    event voteDone(address shareHolder);
    event NewHouseAdded(string id);
    event ShareHolderAdded(address sh);

    enum BallotState { Created, Voting, Ended }
    enum State { Created, Running }

    function etherBalance(address _addr) public view returns (uint256) {
        return _addr.balance;
    }
    

    function startTrading() public onlyRegulator {
        state = State.Running;
    }

    function addHouse(string memory _registrationId, string memory location, uint256 price) 
        public 
        onlyRegulator
        inState(State.Created) 
    {
        House memory h = House(_registrationId, location, price);
        hp.totalValue += price;
        houseRegister.push(h);
        totalHouses += 1;
        emit NewHouseAdded(_registrationId);
    }

    function contains(address _shareHolderAddress) private view returns(bool) {
        for (uint i = 0; i < shareHolders.length; i++) {
            if (shareHolders[i] == _shareHolderAddress) {
                return true;
            }
        }

        return false;
    }

    function addShareHolder(address _shareHolderAddress)
        public
    {   

        if(!contains(_shareHolderAddress)) {
            shareHolderRegistry[_shareHolderAddress] = false;
            shareHolders.push(_shareHolderAddress);
            totalShareHolders++;
            emit ShareHolderAdded(_shareHolderAddress);
        }
        
    }

    function transfer(address _to, uint256 _value) public {
        require (balances[msg.sender] >= _value);
        require(msg.sender == owner);
        balances[msg.sender] -= _value;
        balances[_to]+=_value;
    }

    function buy() public payable {
        uint256 tokenNum = msg.value/tokenPrice; //number of tokens to be bought
        require(msg.value > 0); //the paid money should be more than 0
        require(tokenNum <= shareLimit, "Number of shares exceeded the limit"); //the paid money should be more than 0
        owner.transfer(msg.value); //transfer ether from the buyer to the seller (i.e., tokenOwner)
        balances[owner] -= tokenNum; // the number of tokens held by the token owner decreases
        balances[msg.sender] += tokenNum;  // the buyer gets the corresponding number of tokens
        addShareHolder(msg.sender);
    }
    
    // function sell(uint256 _amount) external {
    //     require(contains(msg.sender), "This user does not hold any shares");
    //     balances[msg.sender] -= _amount;
    //     balances[address(this)] += _amount;
    // }

    function createBallot(string memory _ballotName, string memory _proposal) public {
        ballotState = BallotState.Created;
        ballotName = _ballotName;
        proposal = _proposal;
        ballotInitiator = msg.sender;
    }

    function startVote()
        public
        inBallotState(BallotState.Created)
        onlyBallotInitiator
    {
        ballotState = BallotState.Voting;   
        emit voteStarted();
    }

    function doVote(bool _choice)
        public
        inBallotState(BallotState.Voting)
        returns (bool voted)
    {
        bool found = false;
        if (!shareHolderRegistry[msg.sender]){
            shareHolderRegistry[msg.sender] = true;
            Vote memory v;
            v.shareHolderAddress = msg.sender;
            v.choice = _choice;
            if (_choice){
                resultCount++; //counting on the go
            }
            votes[totalVotes] = v;
            totalVotes++;
            found = true;
        }
        emit voteDone(msg.sender);
        return found;
    }
    
    function endVote()
        public
        inBallotState(BallotState.Voting)
        onlyBallotInitiator
    {
        ballotState = BallotState.Ended;
        finalResult = resultCount;
        emit voteEnded(finalResult);
    }
}