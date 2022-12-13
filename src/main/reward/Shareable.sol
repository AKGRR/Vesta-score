// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { IShareable } from "./interface/IShareable.sol";
import { Math } from "../math/Math.sol";

/**
 * You can seek the src/test/reward/Shareable.t.sol file to have an example of how to use it.
 */
abstract contract Shareable is IShareable {
    uint256 public share; // crops per gem    [ray]
    uint256 public stock; // crop balance     [wad]
    uint256 public totalWeight; // [wad]

    //User => Value
    mapping(address => uint256) internal crops; // [wad]
    mapping(address => uint256) internal userShares; // [wad]

    uint256[49] private __gap;

    function _crop() internal virtual returns (uint256);

    function _addShare(address _wallet, uint256 _value) internal virtual {
        if (_value > 0) {
            uint256 wad = Math.wdiv(_value, netAssetsPerShareWAD());
            require(int256(wad) > 0);

            totalWeight += wad;
            userShares[_wallet] += wad;
        }
        crops[_wallet] = Math.rmulup(userShares[_wallet], share);
        emit ShareUpdated(_value);
    }

    function _partialExitShare(address _wallet, uint256 _newShare) internal virtual {
        _exitShare(_wallet);
        _addShare(_wallet, _newShare);
    }

    function _exitShare(address _wallet) internal virtual {
        uint256 value = userShares[_wallet];

        if (value > 0) {
            uint256 wad = Math.wdivup(value, netAssetsPerShareWAD());

            require(int256(wad) > 0);

            totalWeight -= wad;
            userShares[_wallet] -= wad;
        }

        crops[_wallet] = Math.rmulup(userShares[_wallet], share);
        emit ShareUpdated(value);
    }

    function netAssetsPerShareWAD() public view returns (uint256) {
        return (totalWeight == 0) ? Math.WAD : Math.wdiv(totalWeight, totalWeight);
    }

    function getCropsOf(address _target) external view returns (uint256) {
        return crops[_target];
    }

    function getShareOf(address owner) public view override returns (uint256) {
        return userShares[owner];
    }
}