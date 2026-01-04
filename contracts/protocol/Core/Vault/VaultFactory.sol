//SPDX-License-Identifier:MIT
pragma solidity ^0.8.33;

import "contracts/protocol/Interfaces/IRegistry.sol";

interface VaultInit {
    function initialize(
        address _denominationAsset,
        address _vaultAddressProvider,
        string memory _name,
        string memory _symbol
    ) external;

    function UUID() external view returns (bytes32);
}

contract VaultFactory {
    event VaultCreated(address vault, address impl);

    address private immutable REGISTRY;

    // 虽然不是UUPS模式， 但还是给个UUID防止clone的impl不对
    bytes32 private immutable UUID = keccak256("StrategyAggregatorV1");
    bytes4 private immutable UUID_SELECTOR = bytes4(keccak256("UUID()"));

    modifier onlyOwner() {
        require(IRegistry(REGISTRY).getOwner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    constructor(address _registry) {
        REGISTRY = _registry;
    }

    function createVault(
        address _impl,
        address _denominationAsset,
        string memory _name,
        string memory _symbol
    ) external onlyOwner returns (address) {
        require(_checkImpl(_impl), "VaultFactory: invalid impl");
        address instance = _clone(_impl);
        VaultInit(instance).initialize(_denominationAsset, REGISTRY, _name, _symbol);
        IRegistry(REGISTRY).registryVault(instance);
        return instance;
    }

    function _checkImpl(address _impl) private view returns (bool) {
        if (_impl == address(0)) {
            return false;
        }
        if (_impl.code.length == 0) {
            return false;
        }
        (bool ok, bytes memory ret) = _impl.staticcall(abi.encodeWithSelector(UUID_SELECTOR));
        if (!ok || ret.length != 32) {
            return false;
        }
        if (VaultInit(_impl).UUID() != UUID) {
            return false;
        }
        return true;
    }

    function _clone(address _impl) private returns (address instance_) {
        assembly {
            let ptr := mload(0x40)

            mstore(ptr, hex"3d602d80600a3d3981f3")
            mstore(add(ptr, 0x0a), hex"363d3d373d3d3d363d73")
            mstore(add(ptr, 0x1e), shl(0x60, _impl))
            mstore(add(ptr, 0x32), hex"5af43d82803e903d91602b57fd5bf3")
            instance_ := create(0, ptr, 0x37)
        }
        require(instance_ != address(0), "CREATE_FAILED");
        emit VaultCreated(instance_, _impl);
        return instance_;
    }
}
