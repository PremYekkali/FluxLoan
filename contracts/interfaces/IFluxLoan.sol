// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IFluxLoan {
    function registerLender(
        address token
    ) external;

    function whitelistToken(
        address token,
        bool isAllowed
    ) external;

    function setFlashFeeBps(
        uint16 flashFeeBps
    ) external;

    function setPlatformFeeShareBps(
        uint16 platformFeeShareBps
    ) external;

    function isTokenWhitelisted(
        address token
    ) external view returns (bool);

    function isLenderRegistered(
        address lender,
        address token
    ) external view returns (bool);

    function getFlashFeeBps()
        external
        view
        returns (uint16);

    function getPlatformFeeShareBps()
        external
        view
        returns (uint16);
}