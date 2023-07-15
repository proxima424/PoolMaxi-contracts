pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "../IRewardRouter.sol";
import "../PMContest.sol";
import "../PMFactory.sol";

contract stakedGLP {
    function transfer(address _recipient, uint256 _amount) external returns (bool);
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function balanceOf(address _account) external view returns (uint256);
}

contract GLP is Test{

    PMFactory public factory;

    address constant glpRewardRouter = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;
    address constant stakedGlp = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;

    IRewardRouter router = IRewardRouter(glpRewardRouter);
    stakedGLP glp = stakedGLP(stakedGlp);

    address public me = makeAddr("me");
    address public one = makeAddr("one");
    address public two = makeAddr("two");
    address public three = makeAddr("three");

    uint256 arbitrumFork;
    function setUp() public {
        arbitrumFork = vm.createFork("https://rpc.ankr.com/arbitrum");
        vm.prank(me);
        factory = new PMFactory();
    }

    // testing of the working of the GLP tokens 
    function testMintingGLP() public {
        vm.selectFork(arbitrumFork);
        vm.rollFork(1114e5);
        vm.startPrank(two);
        vm.deal(one, 10 ether);

        // minting stakedGLP
        console.log(router.mintAndStakeGlpETH{value : 1 ether}(0, 0));
        // checking the balance of stakedGlp
        uint bal = glp.balanceOf(msg.sender);
        console.log(bal);
        // should revert the transfer just after minting as there is 15 minutes cooldown in the protocol
        vm.expectRevert(glp.transfer(two, bal));
        // travelling through blocks in future of that previous block
        vm.rollfork(11141e4);
        console.log(glp.transfer(two, bal));
        uint bal = glp.balanceOf(two);

        vm.stopPrank();
    }

    // making a contest and three participants participating in that contest
    function testContestMaking() public {
        vm.selectFork(arbitrum);
        vm.rollFork(1114e5);
        vm.deal(one, 10 ether);
        vm.deal(two, 10 ether);
        vm.deal(three, 10 ether);
        
        // deploying a new contest
        vm.prank(me);
        (address _contest, uint contestId) = factory.deployNewContest(11142e4, stakedGlp, 11143e4, glpRewardRouter, stakedGlp);
        PMcontest contest = PMcontest(_contest);

        // minting stakedGLP
        vm.prank(one);
        uint oneGlp = router.mintAndStakeGlpETH{value : 1 ether}(0, 0);
        vm.prank(two);
        uint twoGlp = router.mintAndStakeGlpETH{value : 2 ether}(0, 0);
        vm.prank(three);
        uint threeGlp = router.mintAndStakeGlpETH{value : 3 ether}(0, 0);

        // transferring the GLP
        vm.rollFork(11141e4);
        vm.prank(one);
        glp.transfer(contest, oneGlp);
        vm.prank(two);
        glp.transfer(contest, twoGlp);
        vm.prank(three);
        glp.transfer(contest, threeGlp);

        // after the contest ends
        vm.rollFork(111431e3);
        vm.startPrank(me);
        uint winnerIndex = factory.contestSetWinner(contestId);
        uint winningAmount = factory.redeemContestAwards(contestId);
        vm.stopPrank();

        // redeeming awards by participants
        vm.prank(one);
        contest.reclaimGLP();

        vm.prank(two);
        contest.reclaimGLP();

        vm.prank(three);
        contest.reclaimGLP();

        // checking the balances
        glp.balanceOf(one);
        glp.balanceOf(two);
        glp.balanceOf(three);
    }
}
