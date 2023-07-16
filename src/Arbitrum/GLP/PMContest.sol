// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";

import {ConfirmedOwner} from "@chainlink/src/v0.8/ConfirmedOwner.sol";
import {VRFV2WrapperConsumerBase} from "node_modules/@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol";
import {VRFv2DirectFundingConsumer} from "./VRF2.sol";

import {IRewardRouter} from "./IRewardRouter.sol";
import {IContest} from "./IContest.sol";

// Chainlink implements ownership modules in VRFv2DirectFundingConsumer
contract PMcontest is IContest, ReentrancyGuard, VRFv2DirectFundingConsumer {
    /*//////////////////////////////////////////////////////////////
                            ERRORS
    //////////////////////////////////////////////////////////////*/

    error PM_ZeroAmount(address actor);
    error PM_DeadlinePassed(address actor, uint256 currentTime);
    error PM_DepositFailed(address actor);  
    error PM_CanNotWithdraw(address actor, uint256 currentTime);
    error PM_CanNotDoubleDeposit(address actor);
    error PM_FailedToWithdraw(address actor);

    /*//////////////////////////////////////////////////////////////
                              Contest State
    //////////////////////////////////////////////////////////////*/

    uint256 public immutable override depositDeadline;
    uint256 public immutable override withdrawStart;
    address public immutable override GLPaddress;
    address public immutable rewardRouter;
    address public immutable wethAddress;

    bool public canWithdraw = false;

    uint256 public totalPoolTokens;
    uint256 public override winnerReward;
    uint256 public chainlinkRandomNumber;
    // address public override winnerAddress;
    uint public winnerIndex = type(uint).max;

    /*//////////////////////////////////////////////////////////////
                              Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(
        uint256 _depositDeadline,
        address _GLPaddress,
        uint256 _withdrawStart,
        address _rewardRouter,
        address _wethAddress
    ) VRFv2DirectFundingConsumer() {
        depositDeadline = _depositDeadline;
        GLPaddress = _GLPaddress;
        withdrawStart = _withdrawStart;
        rewardRouter = _rewardRouter;       // also can be made as constant
        wethAddress = _wethAddress;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    function _checkDepositDeadline(uint256 currentTimestamp) private {          // can't we have just used block.timestamp without argument
        if (currentTimestamp > depositDeadline) {
            revert PM_DeadlinePassed(msg.sender, currentTimestamp);
        }
    }

    modifier checkDepositDeadline() {
        _checkDepositDeadline(block.timestamp);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                              USER OPERATIONS
    //////////////////////////////////////////////////////////////*/

    // User needs to approve this contract of pool token first
    function depositGLP(uint256 amount)
        external
        override
        nonReentrant
        checkDepositDeadline()
        returns (uint, uint)
    {
        if (hasDeposited[msg.sender]) {
            revert PM_CanNotDoubleDeposit(msg.sender);
        }
        if (amount == 0) {
            revert PM_ZeroAmount(msg.sender);
        }

        bool success = IERC20(GLPaddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert PM_DepositFailed(msg.sender);
        } else {
            totalPoolTokens += amount;
            return _mint(msg.sender, amount);
        }
    }

    function reclaimGLP() public nonReentrant returns (uint256 amount) {
        require(canWithdraw);
        if (block.timestamp < withdrawStart) {
            revert PM_CanNotWithdraw(msg.sender, block.timestamp);
        }
        if (hasDeposited[msg.sender]) {
            bool success = IERC20(GLPaddress).transfer(msg.sender, userToDepositAmount[msg.sender]);
            if (!success) {
                revert PM_FailedToWithdraw(msg.sender);
            }
        if (userToIndices[msg.sender].startIndex <= winnerIndex && userToIndices[msg.sender].endIndex >= winnerIndex) {
            // WETH Transfer the amounts
            // Transfer winnerReward
            IERC20(wethAddress).transfer(msg.sender, winnerReward);
        }

        hasDeposited[msg.sender] = false;
        }
    }

    /*//////////////////////////////////////////////////////////////
                            Owner Operations
    //////////////////////////////////////////////////////////////*/

    // Call requestRandomWords() from Factory contract` to get a requestId
    // Then call getRequestStatus(requestId)

    // Setting Winner and reedeming awards will be coupled in two transactions
    // First called setWinner then PM_redeemAward()
    function setWinner() external onlyOwner returns (uint winnerId) {
        require(block.timestamp >= withdrawStart, "PM_01");
        if (winnerIndex == type(uint).max) {
            // Fetch random number from ChainLink VRF
            // Truncate random number to the range ( 0, totalUsers )
            winnerId = chainlinkRandomNumber % (lastIndex + 1); // getrequeststatus variable use from the chainlink contract
            winnerIndex = winnerId;
        }
    }

    function PM_redeemReward() external onlyOwner nonReentrant returns (uint256) {
        if (block.timestamp < withdrawStart) {
            revert PM_CanNotWithdraw(msg.sender, block.timestamp);
        }
        // require(winnerAddress != address(0));
        // Code to claim rewards from handleRewardRouter Contract
        uint256 prevWethBalance = IERC20(wethAddress).balanceOf(address(this));
        IRewardRouter(rewardRouter).handleRewards(true, false, true, false, false, true, false);
        uint256 wethAmount = IERC20(wethAddress).balanceOf(address(this)) - prevWethBalance;
        // Set winnerReward to wethWinner
        winnerReward = wethAmount;
        // So that users can start withdrawing
        canWithdraw = true;
        return wethAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            Ticketing functionality
    //////////////////////////////////////////////////////////////*/

    mapping(address => bool) public hasDeposited;        
    // This mapping to be used to display alloted Id to the user
    // mapping(address => uint256) public userIndex;       // to be deleted 
    // This used to get winner address from random number
    // mapping(uint256 => address) public indexToUser;    // to be deleted 
    // This is used to return amount back to depositor [NO LOSS PROPERTY]
    mapping(address => uint256) public userToDepositAmount;
    // uint256 public totalUsers;                          // to be deleted
    uint public lastIndex;

    struct indices {
        uint startIndex;
        uint endIndex;
    }

    mapping (address => indices) public userToIndices;

    function _mint(address receiver, uint256 amount) internal returns (uint, uint) {
        hasDeposited[receiver] = true;
        userToDepositAmount[receiver] = amount;

        indices memory position;
        position.startIndex = lastIndex;
        lastIndex += amount;
        position.endIndex = lastIndex - 1 ;
        // uint256 indexAlloted = totalUsers++;
        // userIndex[receiver] = indexAlloted;
        // indexToUser[indexAlloted] = receiver;
        userToIndices[receiver] = position;
        return (position.startIndex, position.endIndex);
    }

    function giveWinnerIndex() external returns (uint){
        require(winnerIndex != type(uint).max);
        return winnerIndex;
    }
}
