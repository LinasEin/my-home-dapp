//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract Ballot {    
    address public ballotAddress;      
    string public ballotName;
    string public proposal;
    uint private resultCount = 0;
    uint public finalResult = 0;
    uint public totalShareHolders = 0;
    uint public totalVotes = 0;
    mapping(uint => vote) private votes;
    mapping(address => shareHolder) public shareHolderRegister;
    State public state;

    struct shareHolder {
        string name;
        bool voted;
    }

    struct vote {
        address shareHolderAddress;
        bool choice;
    }

    enum State { Created, Voting, Ended }
	
    event shareHolderAdded(address sh);
    event voteStarted();
    event voteEnded(uint finalResult);
    event voteDone(address shareHolder);

	constructor(
        string memory _ballotName,
        string memory _proposal) {
        ballotAddress = msg.sender;
        ballotName = _ballotName;
        proposal = _proposal;
        
        state = State.Created;
    }
    
    
	modifier condition(bool _condition) {
		require(_condition);
		_;
	}

	modifier onlyOfficial() {
		require(msg.sender == ballotAddress);
		_;
	}

	modifier inState(State _state) {
		require(state == _state);
		_;
	}
    
    function addVoter(address _shareHolderAddress, string memory _shareHolderName)
        public
        inState(State.Created)
        onlyOfficial
    {
        shareHolder memory sh;
        sh.name = _shareHolderName;
        sh.voted = false;
        shareHolderRegister[_shareHolderAddress] = sh;
        totalShareHolders++;
        emit shareHolderAdded(_shareHolderAddress);
    }

    //declare voting starts now
    function startVote()
        public
        inState(State.Created)
        onlyOfficial
    {
        state = State.Voting;     
        emit voteStarted();
    }

    //voters vote by indicating their choice (true/false)
    function doVote(bool _choice)
        public
        inState(State.Voting)
        returns (bool voted)
    {
        bool found = false;
        
        if (bytes(shareHolderRegister[msg.sender].name).length != 0 
        && !shareHolderRegister[msg.sender].voted){
            shareHolderRegister[msg.sender].voted = true;
            vote memory v;
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
    
    //end votes
    function endVote()
        public
        inState(State.Voting)
        onlyOfficial
    {
        state = State.Ended;
        finalResult = resultCount;
        emit voteEnded(finalResult);
    }
}