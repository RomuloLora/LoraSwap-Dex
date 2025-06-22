// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LoraDiamond.sol";

/**
 * @title DiamondCutFacet
 * @dev Facet para gerenciar cortes no diamond
 */
contract DiamondCutFacet {
    
    function diamondCut(
        IDiamondCut.FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }
} 