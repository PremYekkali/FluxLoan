// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IFluxLoanReceiver {
    /**
     * @notice Handles borrowed liquidity execution.
     * @param initiator Flash loan initiator.
     * @param token Borrowed token address.
     * @param amount Borrowed token amount.
     * @param fee Flash loan fee amount.
     * @param data Arbitrary execution calldata.
     */
    function executeOperation(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}