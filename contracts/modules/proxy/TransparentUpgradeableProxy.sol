// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "./UpgradeableProxy.sol";

/**
 * @title TransparentUpgradeableProxy
 * @dev Proxy transparente que delega chamadas para implementação
 */
contract TransparentUpgradeableProxy is UpgradeableProxy {
    
    bytes32 private constant _ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    
    constructor(
        address _implementation,
        address _admin,
        bytes memory data
    ) UpgradeableProxy(_implementation, _admin) {
        if (data.length > 0) {
            Address.functionDelegateCall(_implementation, data);
        }
    }
    
    /**
     * @dev Modifier para verificar se a chamada é do admin
     */
    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }
    
    /**
     * @dev Muda o admin
     */
    function changeAdmin(address newAdmin) external override ifAdmin {
        address oldAdmin = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @dev Atualiza a implementação
     */
    function upgradeTo(address newImplementation) external override ifAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    /**
     * @dev Atualiza a implementação e chama função
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external override ifAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
        
        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }
    
    /**
     * @dev Retorna o admin do storage slot
     */
    function _getAdmin() internal view override returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }
    
    /**
     * @dev Define o admin no storage slot
     */
    function _setAdmin(address newAdmin) internal override {
        require(newAdmin != address(0), "Invalid admin");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }
    
    /**
     * @dev Fallback para delegar chamadas
     */
    function _fallback() internal override {
        _delegate(_getImplementation());
    }
    
    /**
     * @dev Delega chamada para implementação
     */
    function _delegate(address _implementation) internal override {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    /**
     * @dev Fallback function
     */
    fallback() external payable override {
        _fallback();
    }
    
    /**
     * @dev Receive function
     */
    receive() external payable override {}
} 