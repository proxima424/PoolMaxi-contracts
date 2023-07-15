// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IContest {
    // Constructor will take

    // Stores address of the RewardGLP contract
    // Implemented as address public override claimRewardContract
    // To be set via constructor
    function claimRewardContract() external view returns (address);

    // Implemented as uint256 public override start_blockNumber
    // To be set via constructor
    function start_blockNumber() external view returns (uint256);

    // Implemented as uint256 public override end_blockNumber
    // To be set via constructor
    function end_blockNumber() external view returns (uint256);

    // Implemented as bool public override can_withdraw;
    // Initially as false :)
    function can_withdraw() external view returns (bool);

    // Returns address of the winner
    // Implemented as address public override contest_winner
    // Initially address(0)
    function contest_winner() external view returns (address);

    // Returns GLP Tokens balance
    // IERC20(glp).balanceOf(address(this))
    function get_GLPBalance() external;

    // 1 for "deployed and is accepting deposits"
    // 2 for "deployed and is not accepting deposits"
    // 3 for "deployed and rewards claiming under process"
    // 4 for "deployed and users can withdraw "
    // 5 for "contest over bitch"
    // Implemented via some math over block.number
    function status() external view returns (uint256);

    // Checks status() of the contest
    // To be called from the user's address
    // He needs to approve this contract of GLP tokens
    // Logic of this function implemented via
    // "transferFrom" functionality of ERC20
    function accept_deposit() external returns (uint256);

    // onlyOwner function
    // Checks status() of the contest
    // Calls claimRewardContract's function to claim reward
    // After successful claiming sets can_withdraw() to true
    function claimPooledReward() external returns (bool);

    // onlyOwner function
    // Checks status()
    // Interacts with Chainlink VRF
    // Sets contest_winner
    // Emits event stating winner address
    function set_winner() external returns (address);

    // To be called by user
    // Checks can_withdraw()
    // Checks set_winner() and gives
    // principal_amount + reward back
    // Emits claimed event
    function claim() external returns (uint256);
}
