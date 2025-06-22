// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LoraDiamond.sol";

/**
 * @title OwnershipFacet
 * @dev Facet para gerenciar ownership do diamond
 */
contract OwnershipFacet {
    
    /// @notice Gets the owner of the diamond
    /// @return owner_ The address of the owner
    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }
    
    /// @notice Transfer ownership of the diamond
    /// @param _newOwner The address of the new owner
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }
} 