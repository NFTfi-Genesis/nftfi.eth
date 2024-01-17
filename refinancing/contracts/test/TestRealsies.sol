// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import {ERC20PresetMinterPauser, ERC20} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/* solhint-disable one-contract-per-file */

/**
 * @title Blacklistable Token
 * @dev Allows accounts to be blacklisted by a "blacklister" role
 */
contract TestBlacklistable {
    address public blacklister;
    mapping(address => bool) internal blacklisted;

    event Blacklisted(address indexed _account);
    event UnBlacklisted(address indexed _account);
    event BlacklisterChanged(address indexed newBlacklister);

    /**
     * @dev Throws if argument account is blacklisted
     * @param _account The address to check
     */
    modifier notBlacklisted(address _account) {
        // solhint-disable-next-line custom-errors
        require(!blacklisted[_account], "Blacklistable: account is blacklisted");
        _;
    }

    /**
     * @dev Checks if account is blacklisted
     * @param _account The address to check
     */
    function isBlacklisted(address _account) external view returns (bool) {
        return blacklisted[_account];
    }

    /**
     * @dev Adds account to blacklist
     * @param _account The address to blacklist
     */
    function blacklist(address _account) external {
        blacklisted[_account] = true;
        emit Blacklisted(_account);
    }

    /**
     * @dev Removes account from blacklist
     * @param _account The address to remove from the blacklist
     */
    function unBlacklist(address _account) external {
        blacklisted[_account] = false;
        emit UnBlacklisted(_account);
    }

    function updateBlacklister(address _newBlacklister) external {
        // solhint-disable-next-line custom-errors
        require(_newBlacklister != address(0), "Blacklistable: new blacklister is the zero address");
        blacklister = _newBlacklister;
        emit BlacklisterChanged(blacklister);
    }
}

contract TestRealsies is ERC20PresetMinterPauser, ERC20Permit, TestBlacklistable {
    constructor() ERC20PresetMinterPauser("Realsies", "RRR") ERC20Permit("Realsies") {
        // solhint-disable-previous-line no-empty-blocks
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20PresetMinterPauser, ERC20) notBlacklisted(from) notBlacklisted(to) {
        super._beforeTokenTransfer(from, to, amount);
    }
}

/* solhint-enable one-contract-per-file */
