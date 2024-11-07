// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity ^0.8.0;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SFT1967Proxy is ERC1967Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `_logic`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `_logic`. This will typically be an encoded
     * function call, and allows initializing the storage of the proxy like a Solidity constructor.
     */
    constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data){
        _changeAdmin(msg.sender);
    }

    modifier onlyAdmin {
        require(_getAdmin() == msg.sender, "Not Admin");
        _;
    }

    /**
     * @dev Returns the current implementation address.
     */

    function getImplementation() external view returns(address){
        return _implementation();
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        _changeAdmin(newAdmin);
    }

    function upgradeTo(address newImplementation) external onlyAdmin {
        _upgradeTo(newImplementation);
    }

}
