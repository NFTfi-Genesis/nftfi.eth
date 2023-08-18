// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "../interfaces/IPermittedAirdrops.sol";
import "../utils/Ownable.sol";

/**
 * @title  PermittedAirdrops
 * @author NFTfi
 * @dev Registry for airdropa supported by NFTfi. Each Airdrop is associated with a boolean permit.
 */
contract PermittedAirdrops is Ownable, IPermittedAirdrops {
    /* ******* */
    /* STORAGE */
    /* ******* */

    /**
     * @notice A mapping from an airdrop to whether that airdrop
     * is permitted to be used by NFTfi.
     */
    mapping(bytes => bool) private airdropPermits;

    /* ****** */
    /* EVENTS */
    /* ****** */

    /**
     * @notice This event is fired whenever the admin sets a ERC20 permit.
     *
     * @param airdropContract - Address of the airdrop contract.
     * @param selector - The selector of the permitted function in the `airdropContract`.
     * @param isPermitted - Signals airdrop permit.
     */
    event AirdropPermit(address indexed airdropContract, bytes4 indexed selector, bool isPermitted);

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @notice Initialize `airdropPermits` with a batch of permitted airdops
     *
     * @param _admin - Initial admin of this contract.
     * @param _airdopContracts - The batch of airdrop contract addresses initially permitted.
     * @param _selectors - The batch of selector of the permitted functions for each `_airdopContracts`.
     */
    constructor(
        address _admin,
        address[] memory _airdopContracts,
        bytes4[] memory _selectors
    ) Ownable(_admin) {
        require(_airdopContracts.length == _selectors.length, "function information arity mismatch");
        for (uint256 i = 0; i < _airdopContracts.length; i++) {
            _setAirdroptPermit(_airdopContracts[i], _selectors[i], true);
        }
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice This function can be called by admins to change the permitted status of an airdrop. This includes
     * both adding an airdrop to the permitted list and removing it.
     *
     * @param _airdropContract - The address of airdrop contract whose permit list status changed.
     * @param _selector - The selector of the permitted function whose permit list status changed.
     * @param _permit - The new status of whether the airdrop is permitted or not.
     */
    function setAirdroptPermit(
        address _airdropContract,
        bytes4 _selector,
        bool _permit
    ) external onlyOwner {
        _setAirdroptPermit(_airdropContract, _selector, _permit);
    }

    /**
     * @notice This function can be called by admins to change the permitted status of a batch of airdrops. This
     * includes both adding an airdop to the permitted list and removing it.
     *
     * @param _airdropContracts - The addresses of the airdrop contracts whose permit list status changed.
     * @param _selectors - the selector of the permitted functions for each airdop whose permit list status changed.
     * @param _permits - The new statuses of whether the airdrop is permitted or not.
     */
    function setAirdroptPermits(
        address[] memory _airdropContracts,
        bytes4[] memory _selectors,
        bool[] memory _permits
    ) external onlyOwner {
        require(
            _airdropContracts.length == _selectors.length,
            "setAirdroptPermits function information arity mismatch"
        );
        require(_selectors.length == _permits.length, "setAirdroptPermits function information arity mismatch");

        for (uint256 i = 0; i < _airdropContracts.length; i++) {
            _setAirdroptPermit(_airdropContracts[i], _selectors[i], _permits[i]);
        }
    }

    /**
     * @notice This function can be called by anyone to get the permit associated with the airdrop.
     *
     * @param _addressSel - The address of the airdrop contract + function selector.
     *
     * @return Returns whether the airdrop is permitted
     */
    function isValidAirdrop(bytes memory _addressSel) external view override returns (bool) {
        return airdropPermits[_addressSel];
    }

    /**
     * @notice This function can be called by admins to change the permitted status of an airdrop. This includes
     * both adding an airdrop to the permitted list and removing it.
     *
     * @param _airdropContract - The address of airdrop contract whose permit list status changed.
     * @param _selector - The selector of the permitted function whose permit list status changed.
     * @param _permit - The new status of whether the airdrop is permitted or not.
     */
    function _setAirdroptPermit(
        address _airdropContract,
        bytes4 _selector,
        bool _permit
    ) internal {
        require(_airdropContract != address(0), "airdropContract is zero address");
        require(_selector != bytes4(0), "selector is empty");

        airdropPermits[abi.encode(_airdropContract, _selector)] = _permit;

        emit AirdropPermit(_airdropContract, _selector, _permit);
    }
}
