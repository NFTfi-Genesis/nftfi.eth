// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.4;

import "../interfaces/INftTypeRegistry.sol";
import "../interfaces/IPermittedPartners.sol";

import "../utils/Ownable.sol";

/**
 * @title  PermittedPartners
 * @author NFTfi
 * @dev Registry for partners permitted for reciving a revenue share.
 * Each partner's address is associated with the percent of the admin fee shared.
 */
contract PermittedPartners is Ownable, IPermittedPartners {
    /* ******* */
    /* STORAGE */
    /* ******* */

    uint256 public constant HUNDRED_PERCENT = 10000;

    /**
     * @notice A mapping from a partner's address to the percent of the admin fee shared with them. A zero indicates
     * non-permitted.
     */
    mapping(address => uint16) private partnerRevenueShare;

    /* ****** */
    /* EVENTS */
    /* ****** */

    /**
     * @notice This event is fired whenever the admin sets a partner's revenue share.
     *
     * @param partner - The address of the partner.
     * @param revenueShareInBasisPoints - The percent (measured in basis points) of the admin fee amount that will be
     * taken as a revenue share for a the partner.
     */
    event PartnerRevenueShare(address indexed partner, uint16 revenueShareInBasisPoints);

    /* *********** */
    /* CONSTRUCTOR */
    /* *********** */

    /**
     * @notice Sets the admin of the contract.
     *
     * @param _admin - Initial admin of this contract.
     */
    constructor(address _admin) Ownable(_admin) {
        // solhint-disable-previous-line no-empty-blocks
    }

    /* ********* */
    /* FUNCTIONS */
    /* ********* */

    /**
     * @notice This function can be called by admins to change the revenue share status of a partner. This includes
     * adding an partner to the revenue share list, removing it and updating the revenue share percent.
     *
     * @param _partner - The address of the partner.
     * @param _revenueShareInBasisPoints - The percent (measured in basis points) of the admin fee amount that will be
     * taken as a revenue share for a the partner.
     */
    function setPartnerRevenueShare(address _partner, uint16 _revenueShareInBasisPoints) external onlyOwner {
        require(_partner != address(0), "Partner is address zero");
        require(_revenueShareInBasisPoints <= HUNDRED_PERCENT, "Revenue share too big");
        partnerRevenueShare[_partner] = _revenueShareInBasisPoints;
        emit PartnerRevenueShare(_partner, _revenueShareInBasisPoints);
    }

    /**
     * @notice This function can be called by anyone to get the revenue share parcent associated with the partner.
     *
     * @param _partner - The address of the partner.
     *
     * @return Returns the partner's revenue share
     */
    function getPartnerPermit(address _partner) external view override returns (uint16) {
        return partnerRevenueShare[_partner];
    }
}
