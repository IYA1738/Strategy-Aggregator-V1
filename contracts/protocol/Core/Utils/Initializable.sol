//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

abstract contract Initializable {
    bool private _initialized;

    modifier Initializer{
        _checkInitialized();
        _initialized = true;
        _;
    }

    function _checkInitialized() private view{
        require(!_initialized, 
        "Initializable: contract is already initialized");
    }
}