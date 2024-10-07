// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

// File contracts/libraries/proxy/UpgradeableProxy.sol

import {Proxy} from "./Proxy.sol";
import {ISafeswapFactory} from "../../interfaces/SafeMoon/ISafeswapFactory.sol";
import {Address} from "../../library/Address.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * factory address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * factory behind the proxy.
 *
 * Upgradeability is only provided internally through {_upgradeTo}. For an externally upgradeable proxy see
 * {TransparentUpgradeableProxy}.
 */
contract UpgradeableProxy is Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial factory specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializating the storage of the proxy like a Solidity constructor.
     */
    function _UpgradeableProxy_init_(address _factory, bytes memory _data) internal {
        assert(_FACTORY_SLOT == bytes32(uint256(keccak256("eip1967.proxy.factoryfactory")) - 1));
        _setFactory(_factory);
        if (_data.length > 0) {
            // solhint-disable-next-line avoid-low-level-calls
            address impl = ISafeswapFactory(_factory).implementation();
            (bool success,) = impl.delegatecall(_data);
            require(success);
        }
    }

    /**
     * @dev Emitted when the factory is upgraded.
     */
    event Upgraded(address indexed factory);

    /**
     * @dev Storage slot with the address of the current factory.
     * This is the keccak-256 hash of "eip1967.proxy.factoryfactory" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 private constant _FACTORY_SLOT = 0xb2101b231486a8a17a16c101f8dde1145d21799358462f57035a227f25614da3;

    /**
     * @dev Returns the current implementation address.
     */
    function _implementation() internal view override returns (address impl) {
        address factory;
        bytes32 slot = _FACTORY_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            factory := sload(slot)
        }

        // call to Factory and get Impl
        impl = ISafeswapFactory(factory).implementation();
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newFactory) internal {
        _setFactory(newFactory);
        emit Upgraded(newFactory);
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setFactory(address newFactory) private {
        require(Address.isContract(newFactory), "UpgradeableProxy: new factory is not a contract");

        bytes32 slot = _FACTORY_SLOT;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, newFactory)
        }
    }
}
