// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Factory Contract is deployed by an EOA which acts as its admin
// Factory Contract deploys Contests and act as its admin
// Therefore, Factory contract acts as an intermediary between us and Contest.sol

/// @author proxima424 <https://github.com/proxima424>
/// @author EJ <https://github.com/etikshajain>

interface IFactory {
    // Implemented as " address public override current_contest "
    // Returns address of the current running contest
    function current_contest() external view returns (address);

    // 0 for "not deployed yet" . {Implementeed via checking whether the address is deployed}
    // 1 for "deployed and is accepting deposits"
    // 2 for "deployed and is not accepting deposits"
    // 3 for "deployed and rewards claiming under process"
    // 4 for "deployed and users can withdraw"
    // 5 for "contest over bitch"
    // This is implemented via calling IContest(_contest).status() function of the deployed contest
    function contest_status(address _contest) external view returns (uint256);

    // Implemented as IERC20(GLPtokensERC20Address).balanceOf(_conteest)
    function total_GLP_deposited(address _contest) external view returns (uint256);

    /*                   ADMIN FUNCTIONS                       */

    // onlyOwner function
    // Checks if the previously deployed contest is over
    // Deploys a new instance of Contest.sol and returns its address
    // Takes in constructor params of Contest.sol
    // Sets current_contest to this new address
    // Emits out new_contest_deployed event
    function deploy_newContest() external view returns (address);

    // onlyOwner function
}
