// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IShareable {
    event ShareUpdated(uint256 val);
    event Flee();
    event Tack(address indexed src, address indexed dst, uint256 wad);

    function getShareOf(address owner) external view returns (uint256);
}
