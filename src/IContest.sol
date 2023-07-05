// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

interface IContest {
   
    /// @notice Function to set the address of the winner
    /// @dev This is only set by the owner
    /// @return Address of the winner
    function giveWinnerIndex() external returns (uint);

    // Being set by owner via PM_redeemAward()
    function winnerReward() external returns (uint256);

    // After the contest is deployed, there's a window of staking QLP
    // A immutable state being set via constructor
    function depositDeadline() external returns (uint256);

    // After this uint256, owner will call handleRewards function of RewardRouter
    // Only after this uint256, users can start withdrawing
    function withdrawStart() external returns (uint256);

    // User can't withdraw before owner redeems rewards
    function canWithdraw() external returns (bool);

    /// @notice Gives the address of fsQLP ERC20 token
    /// @return Address of fsQLP ERC20 token
    function fsQLPaddress() external returns (address);

    /// @notice Function to deposit the QLP token and mint the Representative Tokens
    /// @dev Only when depositDeadline isn't passed
    /// @dev Also checks whetether amount is 0
    /// @return Index of the user that is 
    function depositQLP(uint256 amount) external returns(uint, uint);

    // Non reentrant public function
    // Checks canWithdraw boolean value first
    // Checks mapping to be a non-zero value
    // Fetches amount of representative token msg.sender has == a1
    // Transfers (a1/totalSupply) * totalQLP to msg.sender
    // If msg.sender == winnerAddress, IERC20 transfer him the WETH reward
    // NEED AUDITING ON ROUNDING ERROR TRANSFERS SHIT
    function reclaimQLP() external returns(uint256);

    // onlyOwner function
    // Checks uint256 withdrawStart
    // Caches balanceOf this contract's QLP token in totalQLP(storage)
    // Calls handleRewards of RewardRouter
    // Stores winning WETH amount returned from wethamount handleRewards in Contract Storage
    // Sets canWithdraw to true
    function PM_redeemReward() external returns (uint256);

    // onlyOwner function
    // Checks uint256 withdrawStart
    // Calls before calling PM_redeemAward() function
    // Gets a random number from Chainlink VRF
    // We store index to address in a mapping m1
    // Sets the m1[randomNumber] to winner
    // Flip winnerAddress to this address
    function setWinner() external returns (uint);
}
