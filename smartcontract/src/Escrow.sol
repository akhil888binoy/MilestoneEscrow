// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Escrow {
    struct Stake {
        uint256 amount;
        address senderAddress;
        address receiverAddress;
        Milestone[] milestones;
        Jury[] juries;
        Status status;
        uint256 senderVote;
        uint256 receiverVote;
        bool isActive;
    }

    enum Status {
        applyforJury
    }

    struct Milestone {
        uint256 amount;
        string description;
        bool isCompleted;
        uint256 dueDate;
    }

    struct Jury {
        address juryAddress;
        uint256 stakeAmount;
        bool senderVote;
        bool receiverVote;
    }

  mapping(address => Stake[]) usersStakes;

  modifier onlyJury(address _stakeOwner, uint256 _stakeId) {
    Stake[] storage stakes = usersStakes[_stakeOwner];
    Stake storage getStake = stakes[_stakeId];
    bool isJury = false;

    for (uint256 i = 0; i < getStake.juries.length; i++) {
        if (getStake.juries[i].juryAddress == msg.sender) {
            isJury = true;
            break;
        }
    }
    require(isJury, "Caller is not part of the jury");
    _;
}


modifier onlySender(uint _stakeId){
    Stake [] storage stakes = usersStakes[msg.sender];
    Stake storage getStake = stakes[_stakeId];
    require(getStake.senderAddress == msg.sender , "Only sender of this stake can call this function");
    _;
}

modifier onlySenderAndReceiver(uint _stakeId , address _stakeowner){
    Stake [] storage stakes = usersStakes[_stakeowner];
    Stake storage getStake = stakes[_stakeId];
    require(getStake.senderAddress == msg.sender || getStake.receiverAddress == msg.sender , "Only sender or receiver of this stake can call this function");
    _;
}



modifier onlyInJuryPhase(address _stakeOwner, uint256 _stakeId) {
    Stake[] storage stakes = usersStakes[_stakeOwner];
    Stake storage getStake = stakes[_stakeId];
    require(getStake.status == Status.applyforJury, "Not in jury phase");
    _;
}


    function addStake(address _receiverAddress, address _senderAddress) external payable {
        require(msg.value > 0, "The stake amount must be greater than zero");
        Stake[] storage stakes = usersStakes[msg.sender];
        Stake storage newStake = stakes.push();
        newStake.isActive = false;
        newStake.senderAddress = _senderAddress;
        newStake.receiverAddress = _receiverAddress;
        newStake.senderVote = 0;
        newStake.receiverVote = 0;
    }

    function addMilestone(uint256 _stakeId,  uint256 _dueDate, string memory _description) external payable {
        Stake[] storage stakes = usersStakes[msg.sender];
        Stake storage getStake = stakes[_stakeId];

        Milestone storage newMilestone = getStake.milestones.push();
        newMilestone.amount = msg.value;
        newMilestone.dueDate = _dueDate;
        newMilestone.isCompleted = false;
        newMilestone.description = _description;
    }

    function payMileStone(uint256 _stakeId, uint256 _milestoneId) public payable onlySender(_stakeId) {
        Stake[] storage stakes = usersStakes[msg.sender];
        Stake storage getStake = stakes[_stakeId];

        Milestone storage getMilestone = getStake.milestones[_milestoneId];
        require(getMilestone.amount > 0, "There is not amount to pay ");
        getMilestone.amount = 0;
        getMilestone.isCompleted = true;
        payable(getStake.receiverAddress).transfer(getMilestone.amount);
    }

    function payVoteMileStone( address _stakeowner, uint256 _stakeId, uint256 _milestoneId) public payable {
        Stake[] storage stakes = usersStakes[_stakeowner];
        Stake storage getStake = stakes[_stakeId];

        Milestone storage getMilestone = getStake.milestones[_milestoneId];
        require(getMilestone.amount > 0, "There is not amount to pay ");
        getMilestone.amount = 0;
        getMilestone.isCompleted = true;
        payable(getStake.receiverAddress).transfer(getMilestone.amount);
    }

    function addJury(address _juryAddress, uint256 _stakeId , address _stakeowner) external  {
        Stake[] storage stakes = usersStakes[_stakeowner];
        Stake storage getStake = stakes[_stakeId];
        Jury storage newJury = getStake.juries.push();

        newJury.juryAddress = _juryAddress;
        newJury.stakeAmount = 0;
        newJury.receiverVote = false;
        newJury.senderVote = false;
    }


    function addJuryStake(uint256 _juryId, address _stakeOwner, uint256 _stakeId) external payable onlyJury(_stakeOwner, _stakeId) {
        Stake[] storage stakes = usersStakes[_stakeOwner];
        Stake storage getStake = stakes[_stakeId];
        require(msg.value > 0, "Pledged value must be greater than zero");
        Jury storage getJury = getStake.juries[_juryId];       
        require(getJury.juryAddress == msg.sender, "Only the jury member can pledge their stake");
        getJury.stakeAmount = msg.value;
    }


  function slashJuryStake(address _stakeOwner, uint256 _stakeId, uint256 _juryId) public payable onlyInJuryPhase(_stakeOwner, _stakeId) {
    Stake[] storage stakes = usersStakes[_stakeOwner];
    Stake storage getStake = stakes[_stakeId];
    Jury storage getJury = getStake.juries[_juryId];

    require(getJury.juryAddress != msg.sender, "Juror cannot slash their own stake");
    uint256 juryStakeAmount = getJury.stakeAmount;
    getJury.stakeAmount = 0;
    payable(getStake.receiverAddress).transfer(juryStakeAmount);
}

   function refundAmount(address _stakeOwner, uint256 _stakeId) public payable onlyInJuryPhase(_stakeOwner, _stakeId) {
            Stake[] storage stakes = usersStakes[_stakeOwner];
            Stake storage getStake = stakes[_stakeId];

            uint256 stakeAmount = getStake.amount;
            getStake.amount = 0;
            payable(getStake.senderAddress).transfer(stakeAmount);
        }



   function voteforSender(address _stakeOwner, uint256 _stakeId, uint256 _juryId) external onlyInJuryPhase(_stakeOwner, _stakeId) onlyJury(_stakeOwner, _stakeId) {
            Stake[] storage stakes = usersStakes[_stakeOwner];
            Stake storage getStake = stakes[_stakeId];
            Jury storage getJury = getStake.juries[_juryId];
            
            require(getJury.juryAddress == msg.sender, "Caller must be the jury member");
            require(!getJury.senderVote, "Already voted for sender");

            getJury.senderVote = true;
            getStake.senderVote++;
}

   function voteforReceiver(address _stakeOwner, uint256 _stakeId, uint256 _juryId) external onlyInJuryPhase(_stakeOwner, _stakeId) onlyJury(_stakeOwner, _stakeId) {
            Stake[] storage stakes = usersStakes[_stakeOwner];
            Stake storage getStake = stakes[_stakeId];
            Jury storage getJury = getStake.juries[_juryId];
            
            require(getJury.juryAddress == msg.sender, "Caller must be the jury member");
            require(!getJury.receiverVote, "Already voted for receiver");

            getJury.receiverVote = true;
            getStake.receiverVote++;
}


  function voteWinner(address _stakeOwner, uint256 _stakeId, uint256 _milestoneId) 
    external 
    onlyInJuryPhase(_stakeOwner, _stakeId) 
{
    Stake[] storage stakes = usersStakes[_stakeOwner];
    Stake storage getStake = stakes[_stakeId];

    // Check if the receiver has more votes than the sender
    if (getStake.receiverVote > getStake.senderVote) {
        // Pay the milestone to the receiver
        payVoteMileStone(_stakeOwner, _stakeId, _milestoneId);

        // Iterate in reverse to avoid issues with removal
        for (uint256 i = getStake.juries.length; i > 0; i--) {
            uint256 idx = i - 1; // Safe index calculation
            Jury storage getJury = getStake.juries[idx];

            // Slash the stake of the jury who voted for the sender
            if (getJury.senderVote) {
                slashJuryStake(_stakeOwner, _stakeId, idx);
                removeJuryAtIndex(getStake.juries, idx);
            }
        }
    } else {
        // Refund the sender if they have more votes
        refundAmount(_stakeOwner, _stakeId);

        // Iterate in reverse to avoid issues with removal
        for (uint256 i = getStake.juries.length; i > 0; i--) {
            uint256 idx = i - 1; // Safe index calculation
            Jury storage getJury = getStake.juries[idx];

            // Slash the stake of the jury who voted for the receiver
            if (getJury.receiverVote) {
                slashJuryStake(_stakeOwner, _stakeId, idx);
                removeJuryAtIndex(getStake.juries, idx);
            }
        }
    }
}

// Helper function to remove an element from the array at a given index
function removeJuryAtIndex(Jury[] storage juries, uint256 index) internal {
    // Move the last element to the index being removed and reduce the length
    juries[index] = juries[juries.length - 1];
    juries.pop();
}


    function setStatusApplyForJury(uint256 _stakeId , address _stakeowner) public {
        Stake[] storage stakes = usersStakes[_stakeowner];
        Stake storage getStake = stakes[_stakeId];
        getStake.status = Status.applyforJury;
    }

     function setStatusCancel(uint256 _stakeId , address _stakeowner) public onlyJury(_stakeowner , _stakeId){
        Stake[] storage stakes = usersStakes[_stakeowner];
        Stake storage getStake = stakes[_stakeId];
        delete getStake.status;
    }


    function getStatus(uint256 _stakeId , address _stakeowner) view public returns(Status) {
        Stake[] storage stakes = usersStakes[_stakeowner];
        Stake storage getStake = stakes[_stakeId];
        return getStake.status;
    }

    function getStakes() external view returns (Stake[] memory) {
        return usersStakes[msg.sender];
    }

function getJuryStakes(address _stakeOwner) external view returns (Stake[] memory) {
    Stake[] storage stakes = usersStakes[_stakeOwner];
    
    uint256 juryStakeCount = 0;
    for (uint256 i = 0; i < stakes.length; i++) {
        Stake storage getStake = stakes[i];
        for (uint256 j = 0; j < getStake.juries.length; j++) {
            if (getStake.juries[j].juryAddress == msg.sender) {
                juryStakeCount++;
                break;  
            }
        }
    }

    Stake[] memory juryStakes = new Stake[](juryStakeCount);
    uint256 index = 0;

    for (uint256 i = 0; i < stakes.length; i++) {
        Stake storage getStake = stakes[i];
        for (uint256 j = 0; j < getStake.juries.length; j++) {
            if (getStake.juries[j].juryAddress == msg.sender) {
                juryStakes[index] = getStake;
                index++;
                break;  
            }
        }
    }

    return juryStakes;
}


    function getJuries(uint256 _stakeId) external view returns (Jury[] memory) {
        Stake[] memory stakes = usersStakes[msg.sender];
        Stake memory getStake = stakes[_stakeId];
        Jury[] memory juries = getStake.juries;
        return juries;
    }
}
