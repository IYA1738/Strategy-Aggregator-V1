//SPDX-License-Identifier:MIT
pragma solidity 0.8.33;

library VaultDataBitParse {
    uint256 internal constant DEPOSIT_FEERATE_OFFSET = 0;
    uint256 internal constant WITHDRAW_FEERATE_OFFSET = 16;

    uint256 internal constant MIN_IDLE_OFFSET = 0;
    uint256 internal constant MAX_DEPLOYFUND_OFFSET = 16;
    uint256 internal constant COOLDOWN_OFFSET = 32;
    uint256 internal constant COOLDOWN_BITS = 40;
    uint256 internal constant BIT_ACTIVE = 72;
    uint256 internal constant BIT_PAUSED = 73;
    uint256 internal constant BIT_REENTRANTGUARD = 74;

    uint256 internal constant MIN_DEPOSIT_AMOUNT_E18_OFFSET = 75;
    uint256 internal constant MIN_DEPOSIT_AMOUNT_E18_BITS = 96;

    uint256 internal constant BPS_RATE_BITS = 16;

    error BitOverflow();
    error BitsOutOfRange();

    function _mask(uint256 bits) internal pure returns (uint256) {
        if (bits == 0 || bits > 255) revert BitsOutOfRange();
        return (uint256(1) << bits) - 1;
    }

    function get(uint256 word, uint256 offset, uint256 bits) internal pure returns (uint256) {
        return (word >> offset) & _mask(bits);
    }

    function set(
        uint256 word,
        uint256 offset,
        uint256 bits,
        uint256 value
    ) internal pure returns (uint256) {
        uint256 m = _mask(bits);
        if (value > m) revert BitOverflow();
        uint256 fieldMask = m << offset;
        return (word & ~fieldMask) | ((value & m) << offset);
    }

    function getBool(uint256 word, uint256 bit) internal pure returns (bool) {
        return ((word >> bit) & uint256(1)) == 1;
    }

    function setBool(uint256 word, uint256 bit, bool value) internal pure returns (uint256) {
        uint256 m = uint256(1) << bit;
        return value ? (word | m) : (word & ~m);
    }

    function depositFeeRate(uint256 word) internal pure returns (uint16) {
        return uint16(get(word, DEPOSIT_FEERATE_OFFSET, BPS_RATE_BITS));
    }

    function withdrawFeeRate(uint256 word) internal pure returns (uint16) {
        return uint16(get(word, WITHDRAW_FEERATE_OFFSET, BPS_RATE_BITS));
    }

    function setDepositFeeRate(uint256 word, uint16 value) internal pure returns (uint256) {
        return set(word, DEPOSIT_FEERATE_OFFSET, BPS_RATE_BITS, value);
    }

    function setWithdrawFeeRate(uint256 word, uint16 value) internal pure returns (uint256) {
        return set(word, WITHDRAW_FEERATE_OFFSET, BPS_RATE_BITS, value);
    }

    function minIdleRate(uint256 word) internal pure returns (uint16) {
        return uint16(get(word, MIN_IDLE_OFFSET, BPS_RATE_BITS));
    }

    function maxDeployFundRate(uint256 word) internal pure returns (uint16) {
        return uint16(get(word, MAX_DEPLOYFUND_OFFSET, BPS_RATE_BITS));
    }

    function coolDown(uint256 word) internal pure returns (uint40) {
        return uint40(get(word, COOLDOWN_OFFSET, COOLDOWN_BITS));
    }

    function isActive(uint256 word) internal pure returns (bool) {
        return getBool(word, BIT_ACTIVE);
    }

    function isPaused(uint256 word) internal pure returns (bool) {
        return getBool(word, BIT_PAUSED);
    }

    function isReentrantGuard(uint256 word) internal pure returns (bool) {
        return getBool(word, BIT_REENTRANTGUARD);
    }

    function setMinIdleRate(uint256 word, uint16 value) internal pure returns (uint256) {
        return set(word, MIN_IDLE_OFFSET, BPS_RATE_BITS, value);
    }

    function setMaxDeployFundRate(uint256 word, uint16 value) internal pure returns (uint256) {
        return set(word, MAX_DEPLOYFUND_OFFSET, BPS_RATE_BITS, value);
    }

    function setCoolDown(uint256 word, uint40 value) internal pure returns (uint256) {
        return set(word, COOLDOWN_OFFSET, COOLDOWN_BITS, value);
    }

    function setIsActive(uint256 word, bool value) internal pure returns (uint256) {
        return setBool(word, BIT_ACTIVE, value);
    }

    function setIsPaused(uint256 word, bool value) internal pure returns (uint256) {
        return setBool(word, BIT_PAUSED, value);
    }

    function setIsReentrantGuard(uint256 word, bool value) internal pure returns (uint256) {
        return setBool(word, BIT_REENTRANTGUARD, value);
    }

    function minDepositAmountE18(uint256 word) internal pure returns (uint96) {
        return uint96(get(word, MIN_DEPOSIT_AMOUNT_E18_OFFSET, MIN_DEPOSIT_AMOUNT_E18_BITS));
    }

    function setMinDepositAmountE18(uint256 word, uint96 value) internal pure returns (uint256) {
        return set(word, MIN_DEPOSIT_AMOUNT_E18_OFFSET, MIN_DEPOSIT_AMOUNT_E18_BITS, value);
    }

    function getFlags(uint256 word) internal pure returns (bool, bool, bool) {
        return (isActive(word), isPaused(word), isReentrantGuard(word));
    }
}
