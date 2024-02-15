pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";

import "../src/DYOFarmFactory.sol";
import "../src/DYOFarm.sol";
import "openzeppelin-contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract NitroPoolFactoryTest is Test {
    uint256 mainnetFork;
    IERC20 DEPOSIT_TOKEN = IERC20(0x23B608675a2B2fB1890d3ABBd85c5775c51691d5); // UNISOCKS
    IERC20 REWARD_TOKEN = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F); // DAI
    address HAYDEN = 0x50EC05ADe8280758E2077fcBC08D878D4aef79C3; // hayden.eth
    address SOCK_HOLDER1 = 0x983110309620D911731Ac0932219af06091b6744;
    address SOCK_HOLDER2 = 0x4c9F7207be28278b9DCA129f2e211AcfFf48Fb01;
    address RANDOM_DAI_HOLDER = 0x22DE0b5C40F012782A667cCdaA15406ba1201246;
    string MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    uint256 sock_holder1_original_dai;
    uint256 sock_holder1_original_unisocks;
    uint256 sock_holder2_original_dai;
    uint256 sock_holder2_original_unisocks;

    DYOFarmFactory nitroPoolFactory;
    address nitroPool;

    // Hayden deposits 1000 DAI as rewards for nitro pool which takes UNISOCKs.
    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17937931);

        nitroPoolFactory = new DYOFarmFactory(address(1), address(2));
        vm.prank(HAYDEN);
        nitroPool = nitroPoolFactory.createNitroPool(
            DEPOSIT_TOKEN, REWARD_TOKEN, DYOFarm.Settings(block.timestamp + 100, block.timestamp + 1100)
        );
        vm.prank(HAYDEN);
        IERC20(REWARD_TOKEN).approve(nitroPool, type(uint256).max);
        vm.prank(HAYDEN);
        DYOFarm(nitroPool).addRewards(1000 ether);
        vm.prank(RANDOM_DAI_HOLDER);
        IERC20(REWARD_TOKEN).approve(nitroPool, type(uint256).max);

        vm.prank(SOCK_HOLDER1);
        IERC20(DEPOSIT_TOKEN).approve(nitroPool, type(uint256).max);
        vm.prank(SOCK_HOLDER2);
        IERC20(DEPOSIT_TOKEN).approve(nitroPool, type(uint256).max);

        sock_holder1_original_dai = IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1);
        sock_holder1_original_unisocks = IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER1);
        sock_holder2_original_dai = IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER2);
        sock_holder2_original_unisocks = IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER2);
    }

    // Skip 400 seconds. Holder1 deposits 1 SOCK. Skip 100 seconds. Holder1 withdraws 1 SOCK. Skip 200 seconds.
    // Holder1 deposits 0.1 SOCK. Skip 2000 seconds. Holder1 withdraws 0.1 SOCK.
    function testCase1() public {
        skip(500);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).deposit(1 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(nitroPool), 1 ether);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 0);
        skip(100);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 166666666666666666600);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).withdraw(1 ether);
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_dai + 166666666666666666600);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 0);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(nitroPool), 0);

        skip(200);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).deposit(1 ether / 10);
        skip(2000);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).withdraw(1 ether / 10);
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_dai + 1000 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_unisocks);
    }

    function testCase2() public {
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).deposit(1 ether / 4);
        vm.prank(SOCK_HOLDER2);
        DYOFarm(nitroPool).deposit(1 ether);

        skip(300);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 40000000000000000000);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER2), 160000000000000000000);

        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).harvest();
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_dai + 40000000000000000000);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 0);

        vm.prank(RANDOM_DAI_HOLDER);
        DYOFarm(nitroPool).addRewards(2000 ether);
        skip(400);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 280 ether);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER2), 1280 ether);

        vm.prank(SOCK_HOLDER2);
        DYOFarm(nitroPool).withdraw(0.5 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER2), sock_holder2_original_unisocks - 0.5 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(nitroPool), 0.75 ether);
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER2), 1280 ether);
    }

    function testCase3() public {
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).deposit(1 ether);

        skip(600);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 500 ether);

        (, uint256 currentEndTime) = DYOFarm(nitroPool).settings();
        vm.prank(HAYDEN);
        DYOFarm(nitroPool).setDateSettings(currentEndTime + 1000);

        skip(500);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 500 ether);
    }

    function testCase4() public {
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).deposit(1 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(nitroPool), 1 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_unisocks - 1 ether);
        skip(600);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).harvest();
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_dai + 500 ether);
        (, uint256 currentEndTime) = DYOFarm(nitroPool).settings();
        vm.prank(HAYDEN);
        DYOFarm(nitroPool).setDateSettings(currentEndTime + 1000);
        skip(500);
        assertEq(DYOFarm(nitroPool).pendingRewards(SOCK_HOLDER1), 166666666666666666500);
        skip(10000);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).withdraw(1 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_unisocks);
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_dai + 1000 ether);
        assertEq(IERC20(REWARD_TOKEN).balanceOf(nitroPool), 0);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(nitroPool), 0);
    }

    function testCase5() public {
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).deposit(1 ether);
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_unisocks - 1 ether);
        skip(1000);
        vm.prank(SOCK_HOLDER1);
        DYOFarm(nitroPool).emergencyWithdraw();
        assertEq(IERC20(DEPOSIT_TOKEN).balanceOf(SOCK_HOLDER1), sock_holder1_original_unisocks);
        assertEq(IERC20(REWARD_TOKEN).balanceOf(SOCK_HOLDER1), 0);
    }

    function testCase6() public {
        nitroPoolFactory.setDefaultFee(100);

        vm.prank(HAYDEN);
        address nitroPool2 = nitroPoolFactory.createNitroPool(
            DEPOSIT_TOKEN, REWARD_TOKEN, DYOFarm.Settings(block.timestamp + 100, block.timestamp + 1100)
        );
        vm.prank(HAYDEN);
        IERC20(REWARD_TOKEN).approve(nitroPool2, type(uint256).max);
        vm.prank(HAYDEN);
        DYOFarm(nitroPool2).addRewards(1000 ether);
        assertEq(REWARD_TOKEN.balanceOf(address(nitroPool2)), 990000000000000000000);
        assertEq(REWARD_TOKEN.balanceOf(nitroPoolFactory.feeAddress()), 10000000000000000000);
    }
}
