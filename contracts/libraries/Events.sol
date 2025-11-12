// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Events {
    event LenderRegistered(
        address indexed lender,
        address indexed token
    );

    event TokenWhitelistUpdated(
        address indexed token,
        bool isAllowed
    );

    event FlashFeeUpdated(
        uint16 flashFeeBps
    );

    event PlatformFeeShareUpdated(
        uint16 platformFeeShareBps
    );
}