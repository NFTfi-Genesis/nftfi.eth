// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "../loans/BaseLoan.sol";

contract TestBaseLoan is BaseLoan {
    constructor(address _admin) BaseLoan(_admin) {
        // solhint-disable-previous-line no-empty-blocks
    }
}
