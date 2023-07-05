// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

import {PMcontest} from "./PMcontest.sol";
import {IContest} from "./IContest.sol";

contract PMfactory {
    /*//////////////////////////////////////////////////////////////
                              ERRORS
    //////////////////////////////////////////////////////////////*/
    error PM_notOwner(address actor);
    error PM_zeroAddress();
    error PM_contestDoesNotExist(uint256 id);
    error PM_settingWinnerFailed(uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/
    event PM_ownerChanged(address indexed oldOwner, address indexed newOwner, uint256 time);

    /*//////////////////////////////////////////////////////////////
                              STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    address public owner;
    uint256 public contestCount;
    mapping(uint256=>bool) isContestRunning;
    mapping(uint256=>address) contestAddress;

    /*//////////////////////////////////////////////////////////////
                              MODIFIER LOGIC
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        checkOwner(msg.sender);
        _;
    }

    function checkOwner(address _address) private {
        if (_address != owner) {
            revert PM_notOwner(_address);
        }
    }

    /*//////////////////////////////////////////////////////////////
                              OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function changeOwner(address _address) external onlyOwner {                 
        if (_address == address(0)) {
            revert PM_zeroAddress();
        }
        address oldOwner = owner;
        assembly {
            sstore(owner.slot, _address)
        }
        emit PM_ownerChanged(oldOwner, _address, block.timestamp);
    }

    function deployNewContest(
        uint256 _depositDeadline,
        address _fsQLPaddress,
        uint256 _withdrawStart,
        address _rewardRouter,
        address _wethAddress
    ) external onlyOwner returns (address newContest,uint256 id) {
        newContest = address(new PMcontest(_depositDeadline,_fsQLPaddress,_withdrawStart,_rewardRouter,_wethAddress));
        id = contestCount++;
        isContestRunning[id] = true;
        contestAddress[id] = newContest;
    }

    function contestSetWinner(uint256 _id) onlyOwner external returns(uint winner){                  // to be changed 
        if(contestAddress[_id]==address(0)){
            revert PM_contestDoesNotExist(_id);
        }

        winner = IContest(contestAddress[_id]).setWinner();

        // if(winner == address(0)){
        //     revert PM_settingWinnerFailed(block.timestamp);
        // }


    }

    function redeemContestAwards(uint256 _id) onlyOwner external returns(uint256 winningAmount){
        if(contestAddress[_id]==address(0)){
            revert PM_contestDoesNotExist(_id);
        }
        winningAmount = IContest(contestAddress[_id]).PM_redeemReward();
        isContestRunning[_id] = false;
    }

    function getWinnerIndex(uint256 _id) external returns(uint){           // also to be changed
        return IContest(contestAddress[_id]).giveWinnerIndex();
    }
}
