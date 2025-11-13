// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IFluxLoanReceiver } from "../interfaces/IFluxLoanReceiver.sol";

/**
 * @title MockFlashBorrower
 * @author Prem
 * @notice Mock borrower contract used for flash execution testing.
 */
contract MockFlashBorrower is IFluxLoanReceiver {
    address private immutable i_protocol;

    constructor(address protocol) {
        i_protocol = protocol;
    }

    function executeOperation(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) external override {
        IERC20(token).transfer(
            i_protocol,
            amount + fee
        );
    }
}