// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import { BaseTest, console } from "./base/BaseTest.t.sol";

import "../src/BaseVesta.sol";

contract BaseVestaTest is BaseTest {
    address private owner = generateAddress("Owner", false);
    address[] private usersWithAccess;

    BaseVestaInheritance private underTest;

    function setUp() public {
        vm.startPrank(owner);
        {
            underTest = new BaseVestaInheritance();
            underTest.setUp();

            uint256 size = underTest.getTotalAccess();

            for (uint256 i = 0; i < size; ++i) {
                address user = generateAddress("User With Access", false);
                usersWithAccess.push(user);
                underTest.setPermission(user, bytes1(underTest.ACCESS_LIST(i)));
            }
        }
        vm.stopPrank();
    }

    function test_setUp_thenCallerShouldBeOwner() public {
        underTest = new BaseVestaInheritance();

        vm.prank(usersWithAccess[0]);
        underTest.setUp();

        assertEq(underTest.owner(), usersWithAccess[0]);
    }

    function test_setUp_calledTwice_thenRevertsTheSecondCall() public {
        underTest = new BaseVestaInheritance();
        underTest.setUp();

        vm.expectRevert(ERROR_ALREADY_INITIALIZED);
        underTest.setUp();
    }

    function test_setPermission_asUser_thenReverts() public prankAs(usersWithAccess[0]) {
        vm.expectRevert(NOT_OWNER);
        underTest.setPermission(owner, 0x01);
    }

    function test_setPermission_asOwner_thenGivePermission() public prankAs(owner) {
        address target = address(0x123);
        bytes1 expectedPermission = 0x08;

        underTest.setPermission(target, expectedPermission);

        assertEq(underTest.getPermissionLevel(target), expectedPermission);
    }

    function test_hasPermission_asEachAccessType_thenRevertsOnEveryCallButOne() public {
        uint256 arrayLength = usersWithAccess.length;

        for (uint256 i = 0; i < arrayLength; ++i) {
            vm.startPrank(usersWithAccess[i]);
            {
                for (uint256 y = 0; y < arrayLength; ++y) {
                    if (y != i) {
                        vm.expectRevert(ERROR_INVALID_PERMISSION);
                    }

                    underTest.dynamicSingleAccessTest(y);
                }
            }
            vm.stopPrank();
        }
    }

    function test_nonReentrency_givenNoAttack_thenNothingHappen() public {
        underTest.nonReentrancyTest();
    }

    function test_nonReentrency_givenAnAttack_thenReverts() public {
        vm.expectRevert(ERROR_NON_REETRANCY);
        reentrancyAttack();
    }

    function reentrancyAttack() public {
        (bool success,) =
            address(msg.sender).call(abi.encodeWithSignature("nonReentrancyTest()"));

        if (success) revert("Attack wasn't stopped");
    }

    function test_notZero_givenZeroValue_thenReverts() public {
        vm.expectRevert(ERROR_NUMBER_ZERO);
        underTest.notZeroTest(0);
    }

    function test_notZero_givenNonZeroValue_thenReverts() public {
        underTest.notZeroTest(1);
    }

    function test_clearPermission_givenUserWithAccess_thenReturnsZeroAccess() public {
        address target = usersWithAccess[0];

        vm.prank(owner);
        underTest.setPermission(target, 0x01);

        underTest.clearPermission(target);
        assertEq(underTest.getPermissionLevel(target), 0x00);
    }

    function test_sanitizeMsgValueWithParam_givenETH_thenReturnsMsgValue() public {
        uint256 expectedValue = 25 ether;

        uint256 returnedValue =
            underTest.sanitizeMsgValueTest{value: expectedValue}(address(0), 39 ether);

        assertEq(returnedValue, expectedValue);
    }

    function test_sanitizeMsgValueWithParam_givenTokenAndZeroInMsgValue_thenReturnsParamValue(
    ) public {
        uint256 expectedValue = 39 ether;
        uint256 returnedValue =
            underTest.sanitizeMsgValueTest{value: 0}(address(0x123), expectedValue);

        assertEq(returnedValue, expectedValue);
    }

    function test_sanitizeMsgValueWithParam_givenERC20AndMsgValue_thenReverts() public {
        uint256 msgValue = 25 ether;
        uint256 paramValue = 39 ether;
        address token = address(0x123);

        vm.expectRevert(
            abi.encodeWithSignature(ERROR_SANITIZE_MSG_VALUE_FAILED_SIGNATURE)
        );

        underTest.sanitizeMsgValueTest{value: msgValue}(token, paramValue);
    }
}

contract BaseVestaInheritance is BaseVesta {
    uint8[] public ACCESS_LIST = [0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80];

    bytes1 public ACCESS_01 = 0x01;
    bytes1 public ACCESS_02 = 0x02;
    bytes1 public ACCESS_04 = 0x04;
    bytes1 public ACCESS_08 = 0x08;

    bytes1 public ACCESS_10 = 0x10;
    bytes1 public ACCESS_20 = 0x20;
    bytes1 public ACCESS_40 = 0x40;
    bytes1 public ACCESS_80 = 0x80;

    function getTotalAccess() external view returns (uint256) {
        return ACCESS_LIST.length;
    }

    function setUp() external initializer {
        __BASE_VESTA_INIT();
    }

    function dynamicSingleAccessTest(uint256 accessId)
        external
        hasPermission(bytes1(ACCESS_LIST[accessId]))
    { }

    function nonReentrancyTest() external nonReentrant returns (bool success) {
        (success,) =
            address(msg.sender).call(abi.encodeWithSignature("reentrancyAttack()"));
    }

    function notZeroTest(uint256 value) external notZero(value) { }

    function clearPermission(address _user) external {
        _clearPermission(_user);
    }

    function sanitizeMsgValueTest(address token, uint256 value)
        external
        payable
        returns (uint256)
    {
        return _sanitizeMsgValueWithParam(token, value);
    }
}
