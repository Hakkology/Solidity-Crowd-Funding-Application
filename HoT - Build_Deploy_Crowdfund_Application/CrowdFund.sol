// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "./IERC20.sol";

contract CrowdFund {

    event Launch(
        uint id,
        address indexed creator,
        uint goal,
        uint32 startAt,
        uint32 endAt
    );

    event Cancel(uint id);
    event Claim(uint id);
    event Refund(uint indexed id, address indexed caller, uint amount);
    event Pledge(uint indexed id, address indexed caller, uint amount);
    event Unpledge(uint indexed id, address indexed caller, uint amount);

    struct Campaign {
        address creator;
        uint goal;
        uint pledged;
        uint32 startAt;
        uint32 endAt;
        bool IsClaimed;
    }

    IERC20 public immutable token;
    uint public count;
    mapping (uint => Campaign) public campaigns;
    mapping (uint => mapping(address => uint)) public pledgedAmount;

    constructor (address _token) {
        token = IERC20(_token);
    }

    function launch(
        uint _goal,
        uint32 _startAt,
        uint32 _endAt
    ) external {
        require(_startAt >= block.timestamp, "start date is in the past.");
        require(_endAt >= _startAt, "end date is less than start date");
        require(_endAt <= block.timestamp + 90 days, "end date is larger than max duration");

        count +=1;
        campaigns[count] = Campaign({
            creator: msg.sender,
            goal: _goal,
            pledged: 0,
            startAt: _startAt,
            endAt: _endAt,
            IsClaimed: false
        });

        emit Launch(count, msg.sender, _goal, _startAt, _endAt);
    }

    function cancel (uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "Not the Creator.");
        require(block.timestamp < campaign.startAt, "Already started.");
        delete campaigns[_id];
        emit Cancel(_id);
    }

    function pledge (uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp >= campaign.startAt, "Campaign has not started yet.");
        require(block.timestamp <= campaign.endAt, "Campaign has ended.");

        campaign.pledged += _amount;
        pledgedAmount[_id][msg.sender] += _amount;
        token.transferFrom(msg.sender, address(this), _amount);

        emit Pledge(_id, msg.sender, _amount);
    }

    function unpledge (uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= campaign.endAt, "Campaign ended.");
        
        campaign.pledged -= _amount;
        pledgedAmount[_id][msg.sender] -= _amount;
        token.transfer(msg.sender, _amount);

        emit Unpledge(_id, msg.sender, _amount);
    }

    function claim (uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(msg.sender == campaign.creator, "Not the Creator.");
        require(block.timestamp > campaign.endAt, "Campaign not ended.");
        require(campaign.pledged >= campaign.goal, "Pledged amount is less than the goal.");
        require(!campaign.IsClaimed, "Campaign already claimed.");

        campaign.IsClaimed = true;
        token.transfer(msg.sender, campaign.pledged);

        emit Claim(_id);
    }

    function refund (uint _id) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.endAt, "Campaign not ended.");
        require(campaign.pledged < campaign.goal, "pledged amount is less than the goal.");

        uint bal = pledgedAmount[_id][msg.sender];
        pledgedAmount[_id][msg.sender]=0;
        token.transfer(msg.sender, bal);

        emit Refund(_id, msg.sender, bal);
    }

}