// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IFluxLoan } from "./interfaces/IFluxLoan.sol";
import { IFluxLoanReceiver } from "./interfaces/IFluxLoanReceiver.sol";
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
    using SafeERC20 for IERC20;

    /// @dev Tracks whether a token is approved for protocol usage.
    mapping(address token => bool isWhitelisted)
        private s_whitelistedTokens;

    /// @dev Flash loan fee charged to borrowers in basis points.
    uint16 private s_flashFeeBps;

    /// @dev Percentage of flash loan fee retained by protocol.
    uint16 private s_platformFeeShareBps;

    /**
    * @dev Tracks lender contribution during flash execution.
    */
    struct LenderContribution {
        address lender;
        uint256 amount;
    }

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
    * @dev Sources liquidity from approved lenders.
    * @param token ERC20 token address.
    * @param lenders Ordered lender list.
    * @param amount Required liquidity amount.
    * @param receiver Liquidity receiver address.
    */
    function _sourceLiquidity(
        address token,
        address[] calldata lenders,
        uint256 amount,
        address receiver
    )
        internal
        returns (
            LenderContribution[] memory contributions,
            uint256 contributionCount
        )
    {
        IERC20 erc20Token = IERC20(token);

        contributions = new LenderContribution[](lenders.length);

        uint256 accumulatedAmount;
        uint256 lenderCount = lenders.length;

        for (uint256 i; i < lenderCount; ) {
            address lender = lenders[i];

            uint256 lenderBalance = erc20Token.balanceOf(lender);

            if (lenderBalance == 0) {
                unchecked {
                    ++i;
                }

                continue;
            }

            uint256 lenderAllowance = erc20Token.allowance(
                lender,
                address(this)
            );

            if (lenderAllowance == 0) {
                unchecked {
                    ++i;
                }

                continue;
            }

            uint256 usableAmount = lenderBalance < lenderAllowance
                ? lenderBalance
                : lenderAllowance;

            uint256 remainingAmount = amount - accumulatedAmount;

            if (usableAmount > remainingAmount) {
                usableAmount = remainingAmount;
            }

            if (usableAmount == 0) {
                unchecked {
                    ++i;
                }

                continue;
            }

            erc20Token.safeTransferFrom(
                lender,
                receiver,
                usableAmount
            );

            contributions[contributionCount] = LenderContribution({
                lender: lender,
                amount: usableAmount
            });

            ++contributionCount;

            accumulatedAmount += usableAmount;

            emit Events.LiquiditySourced(
                lender,
                token,
                usableAmount
            );

            if (accumulatedAmount == amount) {
                break;
            }

            unchecked {
                ++i;
            }
        }

        if (accumulatedAmount != amount) {
            revert Errors.InsufficientLiquidity();
        }
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

    /**
    * @notice Executes atomic flash liquidity operation.
    * @param token ERC20 token address.
    * @param lenders Ordered lender list.
    * @param amount Required liquidity amount.
    * @param receiver Borrower receiver contract.
    * @param data Arbitrary execution calldata.
    */
    function executeFlashLoan(
        address token,
        address[] calldata lenders,
        uint256 amount,
        address receiver,
        bytes calldata data
    ) external nonReentrant {
        if (!s_whitelistedTokens[token]) {
            revert Errors.TokenNotWhitelisted();
        }

        IERC20 erc20Token = IERC20(token);

        uint256 balanceBefore = erc20Token.balanceOf(
            address(this)
        );

        uint256 fee = (amount * s_flashFeeBps) / MAX_BPS;

        uint256 requiredRepayment = amount + fee;

        (
            LenderContribution[] memory contributions,
            uint256 contributionCount
        ) = _sourceLiquidity(
            token,
            lenders,
            amount,
            receiver
        );

        IFluxLoanReceiver(receiver).executeOperation(
            msg.sender,
            token,
            amount,
            fee,
            data
        );

        uint256 balanceAfter = erc20Token.balanceOf(
            address(this)
        );

        uint256 receivedAmount = balanceAfter - balanceBefore;

        if (receivedAmount < requiredRepayment) {
            revert Errors.InsufficientRepayment();
        }

        uint256 protocolFee = (
            fee * s_platformFeeShareBps
        ) / MAX_BPS;

        uint256 lenderRewardPool = fee - protocolFee;

        for (uint256 i; i < contributionCount; ) {
            LenderContribution memory contribution =
                contributions[i];

            uint256 lenderReward = (
                contribution.amount * lenderRewardPool
            ) / amount;

            erc20Token.safeTransfer(
                contribution.lender,
                contribution.amount + lenderReward
            );

            emit Events.LenderRepaid(
                contribution.lender,
                token,
                contribution.amount,
                lenderReward
            );

            unchecked {
                ++i;
            }
        }

        emit Events.FlashLoanExecuted(
            msg.sender,
            receiver,
            token,
            amount,
            fee
        );
    }
}
