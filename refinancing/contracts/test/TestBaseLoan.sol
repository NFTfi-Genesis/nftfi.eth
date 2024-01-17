// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {BaseLoan} from "../loans/BaseLoan.sol";

contract TestBaseLoan is BaseLoan {
    constructor(address _admin) BaseLoan(_admin) {
        // solhint-disable-previous-line no-empty-blocks
    }
}
