//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

abstract contract TimeDelayOwnable2Step{
    address private owner;
    address private pendingOwner;

    uint256 private constant MIN_DELAY = 1 hours;
    uint256 private startTime;
    uint256 private delay;
    uint256 private pendingDelay;
    uint256 private delayStartTime;
    bool private _initialized;

    event OwnershipTransferred(address previousOwner, address newOwner, uint256 timestamp);
    event AcceptOwnership(address newOwner, uint256 timestamp);
    event SetDelay(uint256 delay);
    event ChangedDelay(uint256 delay);

    modifier onlyOwner{
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function __init_Ownable(
        address _owner,
        uint256 _delay
    ) internal{
        require(_initialized == false, "Initializable: contract is already initialized");
        owner = _owner;
        delay = _delay;
        _initialized = true;
    }

    function transferOwnership(address _pendingOwner) external onlyOwner{
        pendingOwner = _pendingOwner;
        startTime = block.timestamp;
        emit OwnershipTransferred(owner, pendingOwner, block.timestamp);
    }

    function acceptOwnership() external{
        require(pendingOwner != address(0), "Ownable: new owner is the zero address");
        require(block.timestamp >= startTime + delay, "Ownable: ownership not yet transferable");
        owner = pendingOwner;
        pendingOwner = address(0);
        startTime = 0;
        emit AcceptOwnership(owner, block.timestamp);
    }

    function setDelay(uint256 _delay) external onlyOwner{
        require(_delay >= MIN_DELAY, "Ownable: delay too short");
        pendingDelay = _delay;
        delayStartTime = block.timestamp;
        emit SetDelay(_delay);
    }

    function changedDelay() external onlyOwner{
        require(delayStartTime + delay >= block.timestamp, "Ownable: delay not yet changed");
        delay = pendingDelay;
        pendingDelay = 0;
        delayStartTime = 0;
        emit ChangedDelay(delay);
    }

    function getOwner() external view returns(address){
        return owner;
    }

    function getPendingOwner() external view returns(address){
        return pendingOwner;
    }

    function getDelay() external view returns(uint256){
        return delay;
    }

    function getAcceptableTime() external view returns(uint256){
        return startTime + delay;
    }
}