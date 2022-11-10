pragma solidity >=0.6.0 <0.7.0;

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";
import "./DSMath.sol";

contract Staker is DSMath {
    ExampleExternalContract public exampleExternalContract;

    // Mappings
    mapping(address => uint256) public balances;
    mapping(address => uint256) public depositTimestamps;

    // Variables
    uint256 public constant rewardRatePerBlockETH = 0.1 ether;
    /*
        Generic:
        Effective rate per sec: Annual Interest / (365 days/yr * 86400 sec/day) = 1.5854895991882 * 10 ** -9
        1 * 10 ** 27 + Effective Rate Per Second * 10 ** 27
        
        For 5%:
        Effective rate per sec: 0.05 / (365 days/yr * 86400 sec/day) = 1.5854895991882 * 10 ** -9
        1 * 10 ** 27 + (1.5854895991882 * 10 ** -9) * 10 ** 27
    */
    uint256 public constant rewardRatePerBlockPercPerSec = 1000000159422510000000000000;
    uint256 public withdrawalDeadline = block.timestamp + 50 seconds; //120 seconds;
    uint256 public claimDeadline = block.timestamp + 100 seconds; //240 seconds;
    uint256 public currentBlock = 0;

    // Events
    event Stake(address sender, uint256 amount);
    event Received(address sender, uint256 amount);
    event Execute(address sender, uint256 amount);

    modifier withdrawalDeadlineReached(bool requireReached) {
        uint256 timeRemaining = withdrawalTimeLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Withdrawal period is not reached yet");
        } else {
            require(timeRemaining > 0, "Withdrawal period has been reached");
        }
        _;
    }

    modifier claimlDeadlineReached(bool requireReached) {
        uint256 timeRemaining = claimPeriodLeft();
        if (requireReached) {
            require(timeRemaining == 0, "Claim period is not reached yet");
        } else {
            require(timeRemaining > 0, "Claim period has been reached");
        }
        _;
    }

    modifier notCompleted() {
        bool completed = exampleExternalContract.completed();
        require(!completed, "Stake already completed!");
        _;
    }

    constructor(address exampleExternalContractAddress) public {
        exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
    }

    function withdrawalTimeLeft() public view returns (uint256 withdrawalTimeLeft) {
        if (block.timestamp >= withdrawalDeadline) {
            return (0);
        } else {
            return (withdrawalDeadline - block.timestamp);
        }
    }

    function claimPeriodLeft() public view returns (uint256 claimPeriodLeft) {
        if (block.timestamp >= claimDeadline) {
            return (0);
        } else {
            return (claimDeadline - block.timestamp);
        }
    }

    // function stake() public payable withdrawalDeadlineReached(false) claimlDeadlineReached(false) {
    function stake() public payable {
        balances[msg.sender] = balances[msg.sender] + msg.value;
        depositTimestamps[msg.sender] = block.timestamp;
        emit Stake(msg.sender, msg.value);

        console.log("Staked!");
    }

    // function withdraw() public withdrawalDeadlineReached(true) claimlDeadlineReached(false) notCompleted {
    function withdraw() public notCompleted {
        require(balances[msg.sender] > 0, "You have no balance to withdraw!");

        console.log("Amount staked: %s", balances[msg.sender]);
        console.log("Initial block: %s", depositTimestamps[msg.sender]);
        console.log("Final block: %s", block.timestamp);

        uint256 individualBalance = balances[msg.sender];
        uint256 elapsedTimeSec = (block.timestamp - depositTimestamps[msg.sender]);

        uint256 indBalanceRewards = individualBalance + (elapsedTimeSec * rewardRatePerBlockETH);
        uint256 indBalanceRewardsCompound = rmul(individualBalance, rpow(rewardRatePerBlockPercPerSec, elapsedTimeSec));

        console.log("End balance (Fixed): %s", individualBalance);
        console.log("End balance (Compound): %s", indBalanceRewardsCompound);

        balances[msg.sender] = 0;

        // Transfer all ETH via call! (not transfer) cc: https://solidity-by-example/sending-ether
        (bool sent, bytes memory data) = msg.sender.call{value: indBalanceRewardsCompound}("");
        require(sent, "RIP; withdrawal failed :(");
    }

    /*
    Allows any user to repatriate "unproductive" funds that are left in the staking contract 
    past the defined withdrawal period
    */
    // function execute() public claimlDeadlineReached(true) notCompleted {
    function execute() public {
        // exampleExternalContract.restake();
        uint256 contractBalance = address(this).balance;
        exampleExternalContract.complete{value: contractBalance}();
    }

    function restake() public {
        console.log("Restaking requested");
        exampleExternalContract.restake();
    }

    function killTime() public {
        currentBlock = block.timestamp;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }
}
