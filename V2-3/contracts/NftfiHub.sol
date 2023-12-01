// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "./interfaces/INftfiHub.sol";
import "./utils/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./utils/ContractKeys.sol";

/**
 * @title  NftfiHub
 * @author NFTfi
 * @dev Registry for the contracts supported by NFTfi protocol.
 */
contract NftfiHub is Ownable, Pausable, ReentrancyGuard, INftfiHub {
    /* ******* */
    /* STORAGE */
    /* ******* */

    mapping(bytes32 => address) private contracts;

    /* ****** */
    /* EVENTS */
    /* ****** */

    /**
     * @notice This event is fired whenever the admin registers a contract.
     *
     * @param contractKey - Contract key e.g. bytes32('PERMITTED_NFTS').
     * @param contractAddress - Address of the contract.
     */
    event ContractUpdated(bytes32 indexed contractKey, address indexed contractAddress);

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @dev Initializes `contracts` with a batch of permitted contracts
     *
     * @param _admin - Initial admin of this contract.
     * @param _contractKeys - Initial contract keys.
     * @param _contractAddresses - Initial associated contract addresses.
     */
    constructor(
        address _admin,
        string[] memory _contractKeys,
        address[] memory _contractAddresses
    ) Ownable(_admin) {
        _setContracts(_contractKeys, _contractAddresses);
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice Set or update the contract address for the given key.
     * @param _contractKey - New or existing contract key.
     * @param _contractAddress - The associated contract address.
     */
    function setContract(string calldata _contractKey, address _contractAddress) external override onlyOwner {
        _setContract(_contractKey, _contractAddress);
    }

    /**
     * @notice Set or update the contract addresses for the given keys.
     * @param _contractKeys - New or existing contract keys.
     * @param _contractAddresses - The associated contract addresses.
     */
    function setContracts(string[] memory _contractKeys, address[] memory _contractAddresses) external onlyOwner {
        _setContracts(_contractKeys, _contractAddresses);
    }

    /**
     * @notice This function can be called by anyone to lookup the contract address associated with the key.
     * @param  _contractKey - The index to the contract address.
     */
    function getContract(bytes32 _contractKey) external view override returns (address) {
        return contracts[_contractKey];
    }

    /**
     * @notice Set or update the contract address for the given key.
     * @param _contractKey - New or existing contract key.
     * @param _contractAddress - The associated contract address.
     */
    function _setContract(string memory _contractKey, address _contractAddress) internal {
        bytes32 key = ContractKeys.getIdFromStringKey(_contractKey);
        contracts[key] = _contractAddress;

        emit ContractUpdated(key, _contractAddress);
    }

    /**
     * @notice Set or update the contract addresses for the given keys.
     * @param _contractKeys - New or existing contract key.
     * @param _contractAddresses - The associated contract address.
     */
    function _setContracts(string[] memory _contractKeys, address[] memory _contractAddresses) internal {
        require(_contractKeys.length == _contractAddresses.length, "setContracts function information arity mismatch");

        for (uint256 i; i < _contractKeys.length; ++i) {
            _setContract(_contractKeys[i], _contractAddresses[i]);
        }
    }
}
