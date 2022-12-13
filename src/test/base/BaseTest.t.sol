// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";

import { TokenTransferrer } from "../../main/token/TokenTransferrer.sol";

contract BaseTest is Test, TokenTransferrer {
    address internal constant RESERVED_ETH_ADDRESS = address(0);
    uint256 internal constant MAX_UINT = type(uint256).max;

    bytes internal constant NOT_OWNER = "Ownable: caller is not the owner";

    bytes internal constant ERC20_INVALID_BALANCE =
        "ERC20: transfer amount exceeds balance";

    bytes internal constant ERROR_INVALID_CONTRACT =
        abi.encodeWithSignature("InvalidContract()");

    bytes internal constant ERROR_INVALID_ADDRESS =
        abi.encodeWithSignature("InvalidAddress()");

    bytes internal constant ERROR_INVALID_PERMISSION =
        abi.encodeWithSignature("InvalidPermission()");

    bytes internal constant ERROR_CANNOT_BE_NATIVE_CHAIN_TOKEN =
        abi.encodeWithSignature("CannotBeNativeChainToken()");

    bytes internal constant ERROR_NON_REETRANCY =
        abi.encodeWithSignature("NonReentrancy()");

    bytes internal constant ERROR_ALREADY_INITIALIZED =
        "Initializable: contract is already initialized";

    bytes internal constant ERROR_NUMBER_ZERO = abi.encodeWithSignature("NumberIsZero()");

    string internal constant ERROR_SANITIZE_MSG_VALUE_FAILED_SIGNATURE =
        "SanitizeMsgValueFailed(address,uint256,uint256)";

    bytes internal constant ERROR_NOT_ZERO = abi.encodeWithSignature("NumberIsZero()");

    uint256 private seed;

    modifier prankAs(address caller) {
        vm.startPrank(caller);
        _;
        vm.stopPrank();
    }

    function generateAddress(string memory _name, bool _isContract)
        internal
        returns (address)
    {
        return generateAddress(_name, _isContract, 0);
    }

    function generateAddress(string memory _name, bool _isContract, uint256 _eth)
        internal
        returns (address newAddress_)
    {
        seed++;
        newAddress_ = vm.addr(seed);

        vm.label(newAddress_, _name);

        if (_isContract) {
            vm.etch(newAddress_, "Generated Contract Address");
        }

        vm.deal(newAddress_, _eth);

        return newAddress_;
    }

    function _sendETH(address _to, uint256 _amount) internal {
        _performTokenTransfer(address(0), _to, _amount, false);
    }

    function expectTransfer(address _token, address _to, uint256 _amount) internal {
        vm.expectCall(
            _token, abi.encodeWithSignature("transfer(address,uint256)", _to, _amount)
        );
    }

    function expectTransferFrom(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        vm.expectCall(
            _token,
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)", _from, _to, _amount
            )
        );
    }

    function expectMaxApprove(address _token, address _spender) internal {
        expectApprove(_token, _spender, MAX_UINT);
    }

    function expectApprove(address _token, address _spender, uint256 _approvalAmount)
        internal
    {
        vm.expectCall(
            _token,
            abi.encodeWithSignature("approve(address,uint256)", _spender, _approvalAmount)
        );
    }
}
