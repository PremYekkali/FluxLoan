// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IFluxLoan } from "./interfaces/IFluxLoan.sol";
import { Errors } from "./libraries/Errors.sol";
import { Events } from "./libraries/Events.sol";

/**
 * @title FluxLoan
 * @author FluxLoan
 * @notice Wallet native flash liquidity protocol powered by lender supplied idle capital.
 */
contract FluxLoan is IFluxLoan, Ownable, ReentrancyGuard {
    /// @dev Basis points denominator.
    uint16 private constant MAX_BPS = 10_000;

    /**
     * @dev Tracks lender registration status for a token.
     * lender => token => isRegistered
     */
    mapping(address lender => mapping(address token => bool isRegistered))
        private s_registeredLenders;

    /// @dev Tracks whether a token is approved for protocol usage.
    mapping(address token => bool isWhitelisted)
        private s_whitelistedTokens;

    /// @dev Flash loan fee charged to borrowers in basis points.
    uint16 private s_flashFeeBps;

    /// @dev Percentage of flash loan fee retained by protocol.
    uint16 private s_platformFeeShareBps;

    /**
     * @param owner Address receiving protocol ownership.
     * @param flashFeeBps Flash loan fee charged to borrowers.
     * @param platformFeeShareBps Percentage of fees retained by protocol.
     */
    constructor(
        address owner,
        uint16 flashFeeBps,
        uint16 platformFeeShareBps
    ) Ownable(owner) {
        if (flashFeeBps > MAX_BPS) {
            revert Errors.InvalidFeeBps();
        }

        if (platformFeeShareBps > MAX_BPS) {
            revert Errors.InvalidFeeBps();
        }

        s_flashFeeBps = flashFeeBps;
        s_platformFeeShareBps = platformFeeShareBps;
    }

    /**
     * @notice Registers lender liquidity for a whitelisted token.
     * @param token ERC20 token address.
     */
    function registerLender(
        address token
    ) external {
        if (!s_whitelistedTokens[token]) {
            revert Errors.TokenNotWhitelisted();
        }

        s_registeredLenders[msg.sender][token] = true;

        emit Events.LenderRegistered(
            msg.sender,
            token
        );
    }

    /**
     * @notice Adds or removes a token from protocol whitelist.
     * @param token ERC20 token address.
     * @param isAllowed Whitelist status.
     */
    function whitelistToken(
        address token,
        bool isAllowed
    ) external onlyOwner {
        s_whitelistedTokens[token] = isAllowed;

        emit Events.TokenWhitelistUpdated(
            token,
            isAllowed
        );
    }

    /**
     * @notice Updates flash loan fee charged to borrowers.
     * @param flashFeeBps New flash fee in basis points.
     */
    function setFlashFeeBps(
        uint16 flashFeeBps
    ) external onlyOwner {
        if (flashFeeBps > MAX_BPS) {
            revert Errors.InvalidFeeBps();
        }

        s_flashFeeBps = flashFeeBps;

        emit Events.FlashFeeUpdated(
            flashFeeBps
        );
    }

    /**
     * @notice Updates percentage of fee retained by protocol.
     * @param platformFeeShareBps New protocol fee share in basis points.
     */
    function setPlatformFeeShareBps(
        uint16 platformFeeShareBps
    ) external onlyOwner {
        if (platformFeeShareBps > MAX_BPS) {
            revert Errors.InvalidFeeBps();
        }

        s_platformFeeShareBps = platformFeeShareBps;

        emit Events.PlatformFeeShareUpdated(
            platformFeeShareBps
        );
    }

    /**
     * @notice Returns whether token is whitelisted.
     * @param token ERC20 token address.
     */
    function isTokenWhitelisted(
        address token
    ) external view returns (bool) {
        return s_whitelistedTokens[token];
    }

    /**
     * @notice Returns lender registration status for token.
     * @param lender Lender address.
     * @param token ERC20 token address.
     */
    function isLenderRegistered(
        address lender,
        address token
    ) external view returns (bool) {
        return s_registeredLenders[lender][token];
    }

    /**
     * @notice Returns borrower flash fee in basis points.
     */
    function getFlashFeeBps()
        external
        view
        returns (uint16)
    {
        return s_flashFeeBps;
    }

    /**
     * @notice Returns percentage of fee retained by protocol.
     */
    function getPlatformFeeShareBps()
        external
        view
        returns (uint16)
    {
        return s_platformFeeShareBps;
    }
}