pragma solidity ^0.8.15;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import "./IRewardRouter.sol";
contract GLP is Test{
    address constant glpRewardRouter = 0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1;
    address constant stakedGlp = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;
    // address constant weth = 0x5402B5F40310bDED796c7D0F3FF6683f5C0cFfdf;

    IRewardRouter router = IRewardRouter(glpRewardRouter);

    // address public me = makeAddr("me");
    address public one = makeAddr("one");
    address public two = makeAddr("two");

    uint256 arbitrumFork;
    function setUp() public {
        arbitrumFork = vm.createFork("https://arb1.arbitrum.io/rpc");
    }

    function testone() public {
        vm.selectFork(arbitrumFork);
        vm.rollFork(1114e5);
        vm.startPrank(one);
        console.log(router.mintAndStakeGlpETH{value : 1 ether}(0, 0));
        (,bytes memory data) = stakedGlp.call(abi.encodeWithSignature("balanceOf(address)", one));
        console.log(abi.decode(data, (uint)));
        vm.stopPrank();
    }

}