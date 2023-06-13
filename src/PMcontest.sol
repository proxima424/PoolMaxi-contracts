// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

import {ConfirmedOwner} from "../node_modules/@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
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
    address public immutable override fsQLPaddress;
    address public immutable rewardRouter;
    address public immutable wethAddress;

    bool public canWithdraw = false;

    uint256 public totalQLP;
    uint256 public override winnerReward;
    uint256 public chainlinkRandomNumber;
    address public override winnerAddress;

    /*//////////////////////////////////////////////////////////////
                              Constructor
    //////////////////////////////////////////////////////////////*/
    constructor(
        uint256 _depositDeadline,
        address _fsQLPaddress,
        uint256 _withdrawStart,
        address _rewardRouter,
        address _wethAddress
    ) VRFv2DirectFundingConsumer() {
        depositDeadline = _depositDeadline;
        fsQLPaddress = _fsQLPaddress;
        withdrawStart = _withdrawStart;
        rewardRouter = _rewardRouter;
        wethAddress = _wethAddress;
    }

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    function _checkDepositDeadline(uint256 currentTimestamp) private {
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

    // User needs to approve this contract of QLP token first
    function depositQLP(uint256 amount)
        external
        override
        nonReentrant
        checkDepositDeadline()
        returns (uint256 indexId)
    {
        if (hasDeposited[msg.sender]) {
            revert PM_CanNotDoubleDeposit(msg.sender);
        }
        if (amount == 0) {
            revert PM_ZeroAmount(msg.sender);
        }

        bool success = IERC20(fsQLPaddress).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert PM_DepositFailed(msg.sender);
        } else {
            totalQLP += amount;
            return mint(msg.sender, amount);
        }
    }

    function reclaimQLP() public nonReentrant returns (uint256 amount) {
        require(canWithdraw);
        if (block.timestamp < withdrawStart) {
            revert PM_CanNotWithdraw(msg.sender, block.timestamp);
        }
        if (hasDeposited[msg.sender]) {
            bool success = IERC20(fsQLPaddress).transfer(msg.sender, userToDepositAmount[msg.sender]);
            if (!success) {
                revert PM_FailedToWithdraw(msg.sender);
            }
        }
        if (msg.sender == winnerAddress) {
            // WETH Transfer the amounts
            // Transfer winnerReward
            IERC20(wethAddress).transfer(winnerAddress, winnerReward);
        }
    }

    /*//////////////////////////////////////////////////////////////
                            Owner Operations
    //////////////////////////////////////////////////////////////*/

    // Call requestRandomWords() from Factory contract` to get a requestId
    // Then call getRequestStatus(requestId)

    // Setting Winner and reedeming awards will be coupled in two transactions
    // First called setWinner then PM_redeemAward()
    function setWinner() external onlyOwner returns (address) {
        require(block.timestamp >= withdrawStart, "PM_01");
        if (winnerAddress == address(0)) {
            // Fetch random number from ChainLink VRF
            // Truncate random number to the range ( 0, totalUsers )
            uint256 winnerIndex = chainlinkRandomNumber % (totalUsers + 1);
            // Set winner
            winnerAddress = indexToUser[winnerIndex];
            return winnerAddress;
        }
    }

    function PM_redeemReward() external onlyOwner nonReentrant returns (uint256) {
        if (block.timestamp < withdrawStart) {
            revert PM_CanNotWithdraw(msg.sender, block.timestamp);
        }
        require(winnerAddress != address(0));
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
    mapping(address => uint256) public userIndex;
    // This used to get winner address from random number
    mapping(uint256 => address) public indexToUser;
    // This is used to return amount back to depositor [NO LOSS PROPERTY]
    mapping(address => uint256) public userToDepositAmount;
    uint256 public totalUsers;

    function mint(address receiver, uint256 amount) internal returns (uint256) {
        hasDeposited[receiver] = true;
        uint256 indexAlloted = totalUsers++;
        userIndex[receiver] = indexAlloted;
        indexToUser[indexAlloted] = receiver;
        userToDepositAmount[receiver] = amount;
        return indexAlloted;
    }
}
