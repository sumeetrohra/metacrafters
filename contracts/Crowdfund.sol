// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error INVALID_EXPIRY_TIME();
error INVALID_GOAL_AMOUNT();
error PROJECT_EXPIRED();
error PROJECT_NOT_FUNDED_YET();
error CANNOT_WITHDRAW_MORE_THAN_ONCE();
error PROJECT_NOT_EXPIRED();
error UNAUTHORIZED();
error PROJECT_FUNDED();
error NOT_A_BACKER();

contract Crowdfund {
    address private immutable _USDCContract;

    struct ProjectDetails {
        string name;
        string description;
        uint fundingGoal;
        uint expiry;
        address creator;
        uint totalSupplied;
        bool amountWithdrawn;
    }
    mapping (uint => ProjectDetails) public projects;

    // projectId => backer address => amount
    mapping (uint => mapping(address => uint)) public backers;

    uint256 private _counter = 0;

    // Events
    event ProjectCreated(uint id, string name, string description, uint fundingGoal, uint expiry, address creator);
    event ProjectBacked(uint id, uint amount);
    event ProjectFundedAndWithdrawn(uint id, uint totalAmountSupplied);
    event Refunded(uint id, address backer, uint amount);

    constructor(address _ERC20USDCAddress) {
        _USDCContract = _ERC20USDCAddress;
    }

    function createProject(string memory _name, string memory _description, uint _goal, uint _expiry) external returns (uint) {
        if (_expiry <= block.timestamp) {
            revert INVALID_EXPIRY_TIME();
        }
        if (_goal == 0) {
            revert INVALID_GOAL_AMOUNT();
        }
        uint count = _counter;
        _counter++;
        ProjectDetails storage p = projects[count];
        p.name = _name;
        p.description = _description;
        p.fundingGoal = _goal;
        p.expiry = _expiry;
        p.creator = msg.sender;
        p.totalSupplied = 0;
        p.amountWithdrawn = false;
        emit ProjectCreated(count, _name, _description, _goal, _expiry, msg.sender);
        return count;
    }

    // Can only fund if the project is not expired
    function fund(uint _projectId, uint _amount) notExpired(_projectId) external {
        bool success = IERC20(_USDCContract).transferFrom(msg.sender, address(this), _amount);
        require(success);
        ProjectDetails storage p = projects[_projectId];
        p.totalSupplied = p.totalSupplied + _amount;
        backers[_projectId][msg.sender] = backers[_projectId][msg.sender] + _amount;
        emit ProjectBacked(_projectId, _amount);
    }

    // Creator can only transfer funds if project is funded, no amount is withdrawn yet and expiry is reached
    function withdrawFunds(uint _projectId) onlyCreator(_projectId) projectFunded(_projectId) notWithdrawn(_projectId) expired(_projectId) external {
        ProjectDetails storage p = projects[_projectId];
        p.amountWithdrawn = true;
        emit ProjectFundedAndWithdrawn(_projectId, p.totalSupplied);
        bool success = IERC20(_USDCContract).transfer(p.creator, p.totalSupplied);
        require(success);
    }

    // Any backer can call this function, if the funding goal is not met for an expired project
    function refund(uint _projectId) projectNotFunded(_projectId) expired(_projectId) onlyBacker(_projectId) external {
        uint amount = backers[_projectId][msg.sender];
        backers[_projectId][msg.sender] = 0;
        emit Refunded(_projectId, msg.sender, amount);
        bool success = IERC20(_USDCContract).transfer(msg.sender, amount);
        require(success);
    }

    modifier onlyBacker(uint _projectId) {
        if (backers[_projectId][msg.sender] == 0) {
            revert NOT_A_BACKER();
        }
        _;
    }

    modifier notExpired(uint _projectId) {
        ProjectDetails memory p = projects[_projectId];
        if (p.expiry <= block.timestamp) {
            revert PROJECT_EXPIRED();
        }
        _;
    }

    modifier projectFunded(uint _projectId) {
        ProjectDetails memory p = projects[_projectId];
        if (p.totalSupplied < p.fundingGoal) {
            revert PROJECT_NOT_FUNDED_YET();
        }
        _;
    }

    modifier projectNotFunded(uint _projectId) {
        ProjectDetails memory p = projects[_projectId];
        if (p.totalSupplied >= p.fundingGoal) {
            revert PROJECT_FUNDED();
        }
        _;
    }

    modifier notWithdrawn(uint _projectId) {
        ProjectDetails memory p = projects[_projectId];
        if (p.amountWithdrawn) {
            revert CANNOT_WITHDRAW_MORE_THAN_ONCE();
        }
        _;
    }

    modifier expired(uint _projectId) {
        ProjectDetails memory p = projects[_projectId];
        if (p.expiry > block.timestamp) {
            revert PROJECT_NOT_EXPIRED();
        }
        _;
    }

    modifier onlyCreator(uint _projectId) {
        ProjectDetails memory p = projects[_projectId];
        if (msg.sender != p.creator) {
            revert UNAUTHORIZED();
        }
        _;
    }
}
