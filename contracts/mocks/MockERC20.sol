// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice ERC20 token used for testing protocol flows.
 */
contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {}

    /**
     * @notice Mints tokens to target account.
     * @param account Receiver address.
     * @param amount Token amount.
     */
    function mint(
        address account,
        uint256 amount
    ) external {
        _mint(account, amount);
    }
}