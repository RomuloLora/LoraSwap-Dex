// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title UpgradeableProxy
 * @dev Proxy pattern com upgradeability para contratos do LoraSwap-DEX
 */
contract UpgradeableProxy is Proxy, Ownable {
    
    bytes32 private constant _IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant _ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    
    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    
    modifier onlyAdmin() {
        require(msg.sender == _getAdmin() || msg.sender == owner(), "Not admin");
        _;
    }
    
    constructor(address _implementation, address _admin) Ownable(msg.sender) {
        _setImplementation(_implementation);
        _setAdmin(_admin);
    }
    
    /**
     * @dev Retorna a implementação atual
     */
    function implementation() external view virtual returns (address) {
        return _getImplementation();
    }
    
    /**
     * @dev Retorna o admin atual
     */
    function admin() external view virtual returns (address) {
        return _getAdmin();
    }
    
    /**
     * @dev Atualiza a implementação
     */
    function upgradeTo(address newImplementation) external virtual onlyAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    /**
     * @dev Atualiza a implementação e chama função de inicialização
     */
    function upgradeToAndCall(
        address newImplementation,
        bytes calldata data
    ) external virtual onlyAdmin {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
        
        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        }
    }
    
    /**
     * @dev Muda o admin
     */
    function changeAdmin(address newAdmin) external virtual onlyAdmin {
        address oldAdmin = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(oldAdmin, newAdmin);
    }
    
    /**
     * @dev Retorna a implementação atual
     */
    function _implementation() internal view override returns (address) {
        return _getImplementation();
    }
    
    /**
     * @dev Retorna a implementação do storage slot
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }
    
    /**
     * @dev Define a implementação no storage slot
     */
    function _setImplementation(address newImplementation) internal {
        require(Address.isContract(newImplementation), "Not a contract");
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }
    
    /**
     * @dev Retorna o admin do storage slot
     */
    function _getAdmin() internal view virtual returns (address) {
        return StorageSlot.getAddressSlot(_ADMIN_SLOT).value;
    }
    
    /**
     * @dev Define o admin no storage slot
     */
    function _setAdmin(address newAdmin) internal virtual {
        require(newAdmin != address(0), "Invalid admin");
        StorageSlot.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }
    
    /**
     * @dev Receive function
     */
    receive() external payable virtual {}
}

/**
 * @title ProxyAdmin
 * @dev Contrato para gerenciar proxies
 */
contract ProxyAdmin is Ownable {
    
    event ProxyUpgraded(address indexed proxy, address indexed implementation);
    event ProxyAdminChanged(address indexed proxy, address indexed previousAdmin, address indexed newAdmin);
    
    constructor() Ownable(msg.sender) {}
    
    /**
     * @dev Atualiza implementação de um proxy
     */
    function upgrade(UpgradeableProxy proxy, address implementation) external onlyOwner {
        proxy.upgradeTo(implementation);
        emit ProxyUpgraded(address(proxy), implementation);
    }
    
    /**
     * @dev Atualiza implementação e chama função
     */
    function upgradeAndCall(
        UpgradeableProxy proxy,
        address implementation,
        bytes calldata data
    ) external onlyOwner {
        proxy.upgradeToAndCall(implementation, data);
        emit ProxyUpgraded(address(proxy), implementation);
    }
    
    /**
     * @dev Muda admin de um proxy
     */
    function changeProxyAdmin(UpgradeableProxy proxy, address newAdmin) external onlyOwner {
        address previousAdmin = proxy.admin();
        proxy.changeAdmin(newAdmin);
        emit ProxyAdminChanged(address(proxy), previousAdmin, newAdmin);
    }
    
    /**
     * @dev Retorna implementação de um proxy
     */
    function getProxyImplementation(UpgradeableProxy proxy) external view returns (address) {
        return proxy.implementation();
    }
    
    /**
     * @dev Retorna admin de um proxy
     */
    function getProxyAdmin(UpgradeableProxy proxy) external view returns (address) {
        return proxy.admin();
    }
}

/**
 * @title Address
 * @dev Utilitários para endereços
 */
library Address {
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
    
    function functionDelegateCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }
    
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");
        
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }
    
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
} 