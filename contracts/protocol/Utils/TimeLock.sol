// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract Timelock is TimelockController {
    bytes32 public constant EMERGENCY_CANCELLER_ROLE = keccak256("EMERGENCY_CANCELLER_ROLE");

    /// @dev Hard floor for the timelock delay.
    uint256 public immutable MIN_DELAY_FLOOR;

    constructor(
        uint256 minDelay_,
        address[] memory proposers,
        address[] memory executors,
        address admin,                 
        uint256 minDelayFloor_      
    )
        TimelockController(minDelay_, proposers, executors, admin)
    {
        require(minDelay_ >= minDelayFloor_, "Timelock: delay < floor");
        MIN_DELAY_FLOOR = minDelayFloor_;

        // Example: make admin also emergency canceller (optional)
        if (admin != address(0)) {
            _grantRole(EMERGENCY_CANCELLER_ROLE, admin);
        }
    }

    function emergencyCancel(bytes32 id)
        external
        onlyRole(EMERGENCY_CANCELLER_ROLE)
    {
        super.cancel(id);
    }
}