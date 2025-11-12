// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

library Events {

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

    event LiquiditySourced(
        address indexed lender,
        address indexed token,
        uint256 amount
    );

    event LenderRepaid(
        address indexed lender,
        address indexed token,
        uint256 principalAmount,
        uint256 rewardAmount
    );

    event FlashLoanExecuted(
        address indexed initiator,
        address indexed receiver,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
}