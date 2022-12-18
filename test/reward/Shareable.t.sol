// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import "../base/BaseTest.t.sol";
import { Shareable, Math } from "../../src/reward/Shareable.sol";
import { TokenTransferrer } from "../../src/token/TokenTransferrer.sol";

import { MockERC20 } from "../mock/MockERC20.sol";

contract ShareableTest is BaseTest {
    address private userA = generateAddress("UserA", false);
    address private userB = generateAddress("UserB", false);
    address private userC = generateAddress("UserC", false);

    MockERC20 private rewardToken;
    MockERC20 private stakingToken;

    PoolShareable private underTest;

    function setUp() external {
        rewardToken = new MockERC20("Reward", "RT", 18);
        stakingToken = new MockERC20("Staking", "ST", 18);

        vm.label(address(rewardToken), "Reward Token");
        vm.label(address(stakingToken), "Staking Token");

        underTest = new PoolShareable(address(rewardToken), address(stakingToken));

        stakingToken.mint(userA, 10_000e18);
        stakingToken.mint(userB, 10_000e18);
        stakingToken.mint(userC, 10_000e18);
    }

    function test__addShare_asUserA_whenShareIsZero_thenDoNothing()
        external
        prankAs(userA)
    {
        underTest.addShareZeroValue();

        assertEq(underTest.totalWeight(), 0);
        assertEq(underTest.getShareOf(userA), 0);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test__addShare_asUserA_whenFirstDepositor_thenSystemUpdates()
        external
        prankAs(userA)
    {
        underTest.deposit(30e18);

        assertEq(underTest.totalWeight(), 1e18);
        assertEq(underTest.getShareOf(userA), 1e18);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test__addShare_asUserB_givenHigherDepositThanUserA_whenSystemAlreadyHasDepositor_thenSystemUpdates(
    ) external prankAs(userB) {
        changePrank(userA);
        underTest.deposit(30e18);

        changePrank(userB);
        underTest.deposit(45e18);

        assertEq(underTest.totalWeight(), 2.5e18);
        assertEq(underTest.getShareOf(userB), 1.5e18);
        assertEq(underTest.getCropsOf(userB), 0);
    }

    function test__addShare_asUserA_givenAlreadyDeposited_thenUpdatesSysmte()
        external
        prankAs(userA)
    {
        underTest.deposit(30e18);
        underTest.deposit(99.1e18);

        assertEq(underTest.totalWeight(), 4_303_333_333_333_333_333);
        assertEq(underTest.getShareOf(userA), 4_303_333_333_333_333_333);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test__partialExitShare_asUserA_thenUpdatesSystem() external prankAs(userA) {
        underTest.deposit(969.1e18);
        underTest.withdrawal(25.1e18);

        assertEq(underTest.totalWeight(), 974_099_680_115_571_148);
        assertEq(underTest.getShareOf(userA), 974_099_680_115_571_148);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test__exitShare_asUserA_whenBalanceIsZero_thenDoNothing()
        external
        prankAs(userA)
    {
        underTest.exit();
        assertEq(underTest.totalWeight(), 0);
        assertEq(underTest.getShareOf(userA), 0);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test__exitShare_asUserA_thenUpdatesSystem() external prankAs(userA) {
        underTest.deposit(969.1e18);
        underTest.exit();

        assertEq(underTest.totalWeight(), 0);
        assertEq(underTest.getShareOf(userA), 0);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test__exitShare_asUserA_whenOtherDepositor_thenUpdatesSystem()
        external
        prankAs(userA)
    {
        changePrank(userB);
        underTest.deposit(82e18);

        changePrank(userA);
        underTest.deposit(969.1e18);
        underTest.exit();

        assertEq(underTest.totalWeight(), 1e18);
        assertEq(underTest.getShareOf(userA), 0);
        assertEq(underTest.getCropsOf(userA), 0);
    }

    function test_pool_simualtion() external prankAs(address(0x01)) {
        rewardToken.mint(address(underTest), 1.0002e18);

        changePrank(userA);
        underTest.deposit(1821.29e18);

        rewardToken.mint(address(underTest), 0.8002e18);

        changePrank(userB);
        underTest.deposit(302.99e18);

        changePrank(userA);
        underTest.withdrawal(1e18);

        rewardToken.mint(address(underTest), 2.1e18);

        changePrank(userC);
        underTest.deposit(3212.19e18);

        changePrank(userB);
        underTest.exit();

        rewardToken.mint(address(underTest), 7.721e18);

        changePrank(userA);
        underTest.exit();

        changePrank(userC);
        underTest.exit();

        assertEq(rewardToken.balanceOf(userA), 5_393_282_146_721_904_792);
        assertEq(rewardToken.balanceOf(userB), 299_667_966_542_330_732);
        assertEq(rewardToken.balanceOf(userC), 4_928_249_886_735_764_472);
    }
}

contract PoolShareable is Shareable, TokenTransferrer {
    address public rewardToken;
    address public stakingToken;

    uint256 public systemBalance;
    mapping(address => uint256) private balances;

    constructor(address _tokenReward, address _stakingToken) {
        rewardToken = _tokenReward;
        stakingToken = _stakingToken;
    }

    function addShareZeroValue() external {
        _addShare(msg.sender, 0);
    }

    function deposit(uint256 _value) external {
        require(_value > 0, "Value cannot be zero");
        _claim();

        uint256 newShare = 1e18;

        _performTokenTransferFrom(stakingToken, msg.sender, address(this), _value, false);
        balances[msg.sender] += _value;

        if (totalWeight > 0) {
            newShare = (totalWeight * _value) / systemBalance;
        }

        systemBalance += _value;

        _addShare(msg.sender, newShare);
    }

    function withdrawal(uint256 _value) external {
        _claim();

        uint256 newShare = 0;
        uint256 balanceTotal = balances[msg.sender] -= _value;

        if (totalWeight > 0 && balanceTotal > 0) {
            newShare = (totalWeight * balanceTotal) / systemBalance;
        }

        systemBalance -= _value;
        _partialExitShare(msg.sender, newShare);

        _performTokenTransfer(stakingToken, msg.sender, _value, false);
    }

    function exit() external {
        _claim();

        uint256 cachedBalance = balances[msg.sender];

        balances[msg.sender] = 0;
        _exitShare(msg.sender);

        _performTokenTransfer(stakingToken, msg.sender, cachedBalance, false);
    }

    function _crop() internal view override returns (uint256) {
        return _balanceOf(rewardToken, address(this)) - stock;
    }

    function _claim() internal {
        if (totalWeight > 0) {
            share = share + Math.rdiv(_crop(), totalWeight);
        }

        uint256 last = crops[msg.sender];
        uint256 curr = Math.rmul(userShares[msg.sender], share);

        if (curr > last) {
            uint256 sendingReward = curr - last;
            _performTokenTransfer(rewardToken, msg.sender, sendingReward, false);
        }

        stock = _balanceOf(rewardToken, address(this));
    }
}