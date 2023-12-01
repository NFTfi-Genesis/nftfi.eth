// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "../../utils/Ownable.sol";
import "../../utils/ContractKeys.sol";

/**
 * @title  PermittedNFTsAndTypeRegistry
 * @author NFTfi
 * @dev Registry for refinanceable contracts supported by NFTfi.
 * Each refinanceable contract is associated with a refinanceableType.
 */
contract RefinancingAdapterRegistry is Ownable {
    mapping(bytes32 => address) private refinanceableTypes;
    mapping(address => bytes32) private refinanceableContracts;

    /* ****** */
    /* EVENTS */
    /* ****** */

    /**
     * @notice This event is fired whenever the admins register a refinancing type.
     *
     * @param refinanceableType - refinanceable type e.g. bytes32("DIRECT_LOAN_FIXED_OFFER")
     * @param refinancingAdapter - Address of the refinancing adapter contract.
     */
    event TypeUpdated(bytes32 indexed refinanceableType, address indexed refinancingAdapter);

    /**
     * @notice This event is fired whenever the admin sets a new refinanceable contract
     *
     * @param refinanceableContract - Address of the refinanceable contract.
     * @param refinanceableType - refinanceable type e.g. bytes32("DIRECT_LOAN_FIXED_OFFER")
     */
    event NewRefinanceableContract(address indexed refinanceableContract, bytes32 indexed refinanceableType);

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @dev Initialize `refinanceableTypes` with a batch of permitted refinancing types.
     *
     * @param _admin - Initial admin of this contract.
     */
    /*
     * @param _definedRefinanceableTypes - Array of defined refinancing types.
     * @param _refinancingAdapters - Array of refinancing adapter contracts.
     * @param _refinanceableTypes - Array of refinancing types  e.g. "DIRECT_LOAN_FIXED_OFFER"
     * @param _refinanceableContracts - Array of refinanceable contract addresses.
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given Refinanceable Type"
     */
    constructor(
        address _admin,
        string[] memory _definedRefinanceableTypes,
        address[] memory _refinancingAdapters,
        string[] memory _refinanceableTypes,
        address[] memory _refinanceableContracts
    ) Ownable(_admin) {
        _setRefinanceableTypes(_definedRefinanceableTypes, _refinancingAdapters);
        _setRefinanceableContracts(_refinanceableContracts, _refinanceableTypes);
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice Changes the status of a refinanceable contract.
     * This includes both adding a refinanceable contract to the permitted list and removing it.
     *
     * @param _refinanceableContract - Address of the refinanceable contract.
     * @param _refinanceableType - Refinanceable type, e.g., "DIRECT_LOAN_FIXED_OFFER".
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    function setRefinanceableContract(address _refinanceableContract, string memory _refinanceableType)
        external
        onlyOwner
    {
        _setRefinanceableContract(_refinanceableContract, _refinanceableType);
    }

    /**
     * @notice Changes the status of a batch of refinanceable contracts.
     * This includes both adding refinanceable contracts to the permitted list and removing them.
     *
     * @param _refinanceableContracts - Array of refinanceable contract addresses.
     * @param _refinanceableTypes - Array of refinanceable types associated with the refinanceable contracts.
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    function setRefinanceableContracts(address[] memory _refinanceableContracts, string[] memory _refinanceableTypes)
        external
        onlyOwner
    {
        _setRefinanceableContracts(_refinanceableContracts, _refinanceableTypes);
    }

    /**
     * @notice Looks up the refinanceable type associated with a refinanceable contract.
     *
     * @param _refinanceableContract - Address of the refinanceable contract.
     * @return The refinanceable type:
     * - bytes32("") means "not registered"
     * - != bytes32("") means "permitted with the given refinanceable type"
     */
    function getRefinanceableContract(address _refinanceableContract) external view returns (bytes32) {
        return refinanceableContracts[_refinanceableContract];
    }

    /**
     * @notice Looks up the address of the refinanceable adapter associated with the refinanceable contract type.
     *
     * @param _refinanceableContract - Address of the refinanceable contract.
     * @return The address of the refinanceable adapter contract.
     */
    function getRefinancingAdapter(address _refinanceableContract) public view returns (address) {
        bytes32 refinanceableType = refinanceableContracts[_refinanceableContract];
        return getRefinancingAdapterOfType(refinanceableType);
    }

    /**
     * @notice Sets or updates the address of the refinanceable adapter contract for the given refinanceable type.
     * Set address(0) for a refinanceable type to unregister it.
     *
     * @param _refinanceableType - Refinanceable type, e.g., "DIRECT_LOAN_FIXED_OFFER"
     * @param _refinancingAdapter - Address of the refinancing adapter contract that implements the refinanceable
     * behavior for dealing with the correct refinanceable type
     */
    function setRefinanceableType(string memory _refinanceableType, address _refinancingAdapter) external onlyOwner {
        _setRefinanceableType(_refinanceableType, _refinancingAdapter);
    }

    /**
     * @notice Sets or updates the addresses of the refinanceable adapter
     * contracts for the given batch of refinanceable types.
     * Set address(0) for a refinanceable type to unregister it.
     *
     * @param _refinanceableTypes - Array of refinanceable types, e.g., "DIRECT_LOAN_FIXED_OFFER"
     * @param _refinancingAdapters - Array of addresses of the refinancing adapter contracts that implement
     * the refinanceable behavior for dealing with the correct refinanceable type
     */
    function setRefinanceableTypes(string[] memory _refinanceableTypes, address[] memory _refinancingAdapters)
        external
        onlyOwner
    {
        _setRefinanceableTypes(_refinanceableTypes, _refinancingAdapters);
    }

    /**
     * @notice Gets the address of the refinancing adapter contract that implements the given refinanceable type.
     *
     * @param  _refinanceableType - Refinanceable type, e.g., bytes32("DIRECT_LOAN_FIXED_OFFER")
     * @return The address of the refinancing adapter contract.
     */
    function getRefinancingAdapterOfType(bytes32 _refinanceableType) public view returns (address) {
        return refinanceableTypes[_refinanceableType];
    }

    /**
     * @notice Sets or updates the address of the refinancing adapter contract for the given refinanceable type.
     * Set address(0) to unregister a refinanceable type.
     *
     * @param _refinanceableType - Refinanceable type, e.g., "DIRECT_LOAN_FIXED_OFFER"
     * @param _refinancingAdapter - Address of the refinancing adapter contract that implements the
     * refinanceable behavior for dealing with the correct refinanceable type
     */

    function _setRefinanceableType(string memory _refinanceableType, address _refinancingAdapter) internal {
        require(bytes(_refinanceableType).length != 0, "refinanceableType is empty");
        bytes32 refinanceableTypeKey = ContractKeys.getIdFromStringKey(_refinanceableType);

        refinanceableTypes[refinanceableTypeKey] = _refinancingAdapter;

        emit TypeUpdated(refinanceableTypeKey, _refinancingAdapter);
    }

    /**
     * @notice Batch sets or updates the addresses of the refinancing adapter
     * contracts for the given batch of refinanceable types.
     * Set address(0) to unregister a refinanceable type.
     *
     * @param _refinanceableTypes - Array of refinanceable types, e.g., "DIRECT_LOAN_FIXED_OFFER"
     * @param _refinancingAdapters - Array of addresses of the refinancing adapter contracts that implement the
     * refinanceable behavior for dealing with the correct refinanceable type
     */
    function _setRefinanceableTypes(string[] memory _refinanceableTypes, address[] memory _refinancingAdapters)
        internal
    {
        require(
            _refinanceableTypes.length == _refinancingAdapters.length,
            "setRefinanceableTypes function information arity mismatch"
        );

        for (uint256 i; i < _refinancingAdapters.length; ++i) {
            _setRefinanceableType(_refinanceableTypes[i], _refinancingAdapters[i]);
        }
    }

    /**
     * @notice Changes the registered status of a refinanceable contract.
     * This includes both adding a refinanceable contract to the registered list and removing it.
     *
     * @param _refinanceableContract - Address of the refinanceable contract.
     * @param _refinanceableType - Refinanceable type, e.g., "DIRECT_LOAN_FIXED_OFFER".
     * - bytes32("") means "disable this permit"
     * - != bytes32("") means "enable permit with the given NFT Type"
     */
    function _setRefinanceableContract(address _refinanceableContract, string memory _refinanceableType) internal {
        require(_refinanceableContract != address(0), "refinanceableContract is zero address");
        bytes32 refinanceableTypeKey = ContractKeys.getIdFromStringKey(_refinanceableType);

        if (refinanceableTypeKey != 0) {
            require(
                getRefinancingAdapterOfType(refinanceableTypeKey) != address(0),
                "refinanceable type not registered"
            );
        }

        refinanceableContracts[_refinanceableContract] = refinanceableTypeKey;
        emit NewRefinanceableContract(_refinanceableContract, refinanceableTypeKey);
    }

    /**
     * @notice Changes the registered status of multiple refinanceable contracts.
     * This function can only be called by the contract owner.
     * It includes both adding refinanceable contracts to the registered list and removing them.
     *
     * @param _refinanceableContracts - Array of refinanceable contract addresses.
     * @param _refinanceableTypes - Array of refinanceable types associated with
     * the refinanceable contracts, e.g., "DIRECT_LOAN_FIXED_OFFER".
     * - "" means "disable this permit"
     * - != "" means "enable permit with the given NFT Type"
     */
    function _setRefinanceableContracts(address[] memory _refinanceableContracts, string[] memory _refinanceableTypes)
        internal
    {
        require(
            _refinanceableContracts.length == _refinanceableTypes.length,
            "setRefinanceableContracts function information arity mismatch"
        );

        for (uint256 i; i < _refinanceableContracts.length; ++i) {
            _setRefinanceableContract(_refinanceableContracts[i], _refinanceableTypes[i]);
        }
    }
}
