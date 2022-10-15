pragma solidity >=0.7.0 <0.9.0;
// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/utils/Strings.sol";


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
    mapping (address => uint256) public balances;

    // Ballots
    mapping(uint => Ballot) public ballotHistory;
    uint public totalBallots = 0;
    Ballot public currentBallot;
    mapping(uint => Vote) private votes;
    uint private resultCount;

    constructor(string memory _name, string memory _description) payable {
        owner = payable(msg.sender);
        balances[msg.sender] = totalShares;
        hp.name = _name;
        hp.description = _description;
        hp.totalValue = 0;
        state = State.Created;
        addShareHolder(owner);
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

    struct Ballot {
        string ballotId;
        address ballotOwner;
        string proposal;
        uint finalResult;
        uint totalVotes;
        BallotState state;
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
		require(msg.sender == currentBallot.ballotOwner);
		_;
	}

	modifier inBallotState(BallotState _state) {
		require(currentBallot.state == _state, "Voting did not start yet!");
		_;
	}

    modifier canVote(address sender) {
        if (owner != sender) {
            bool found = false;
            for (uint i = 0; i<totalShareHolders; i++) {
                if (shareHolders[i] == sender || owner == sender) {
                    found = true;
                }
            }

            require(found == true, "You have no rights to create ballot!");
        }
		
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

    function removeShareHolder(address _shareHolderAddress)
        public
    {   
        for (uint i = 0; i<totalShareHolders; i++) {
            if (shareHolders[i] == _shareHolderAddress) {
                delete shareHolders[i];
                totalShareHolders--;
            }
        }   
    }

    function transfer(address _to, uint256 _value) public {
        require (balances[msg.sender] >= _value);
        require(msg.sender == owner);
        balances[msg.sender] -= _value;
        balances[_to]+=_value;
    }

    function sellToOwner(uint tokenNum) public payable {
        require(tokenNum <= balances[msg.sender], "Cannot sell shares you do not own");
        address payable receiver = payable(msg.sender);
        receiver.transfer(msg.value);
        if (tokenNum == balances[msg.sender]) {
            removeShareHolder(msg.sender);
        }

        balances[msg.sender] -= tokenNum;
        balances[owner] += tokenNum;        
    }

    function buy(uint tokenNum) public payable {
        uint256 unitPrice = hp.totalValue/totalShares;
        uint requiredWeiBalance = unitPrice * tokenNum;
        require(msg.value == requiredWeiBalance, "Incorrect wei amount submitted!"); 
        require(tokenNum <= shareLimit, "Number of shares exceeded the limit");
        require(balances[owner] >= tokenNum, "There are less than desired amount of shares");
        owner.transfer(msg.value);
        balances[owner] -= tokenNum;
        balances[msg.sender] += tokenNum;
        addShareHolder(msg.sender);
        if (balances[owner] == 0) {
            removeShareHolder(owner);
        }
    }

    function createBallot(string memory _proposal) public canVote(msg.sender) {
        currentBallot = Ballot(Strings.toString(totalBallots), msg.sender, _proposal, 0, 0, BallotState.Created);
        for (uint i = 0; i<totalShareHolders; i++) {
            address sh = shareHolders[i];
            shareHolderRegistry[sh] = false;
        }
    }

    function startVote()
        public
        inBallotState(BallotState.Created)
        onlyBallotInitiator
    {
        currentBallot.state = BallotState.Voting;   
        emit voteStarted();
    }

    function doVote(bool _choice)
        public
        inBallotState(BallotState.Voting)
        canVote(msg.sender)
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
            votes[currentBallot.totalVotes] = v;
            currentBallot.totalVotes++;
            found = true;
        }
        emit voteDone(msg.sender);
        return found;
    }

    function getMyVote() public view canVote(msg.sender) returns (bool vote) {
        for (uint i = 0; i < currentBallot.totalVotes; i++) {
            if (votes[i].shareHolderAddress == msg.sender) {
                return votes[i].choice;
            }
        }
    }

    function endVote()
        public
        inBallotState(BallotState.Voting)
        onlyBallotInitiator
    {
        currentBallot.state = BallotState.Ended;
        currentBallot.finalResult = resultCount;
        ballotHistory[totalBallots] = currentBallot;
        totalBallots++;
        emit voteEnded(currentBallot.finalResult);
    }
}