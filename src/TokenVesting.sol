// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenVesting
 * @dev A token vesting contract that releases ERC20 tokens to a beneficiary
 * according to a vesting schedule with a cliff period.
 * 
 * Features:
 * - 12 months cliff period
 * - 24 months linear vesting after cliff
 * - Total vesting period: 36 months (12 months cliff + 24 months linear)
 * - Monthly releases after cliff period
 */
contract TokenVesting is Context, Ownable {
    using SafeERC20 for IERC20;

    // Events
    event TokensReleased(address token, uint256 amount);
    event TokenVestingRevoked(address token);

    // Beneficiary of tokens after they are released
    address private immutable _beneficiary;
    
    // ERC20 token being vested
    IERC20 private immutable _token;
    
    // Cliff duration in seconds (12 months)
    uint256 private immutable _cliff;
    
    // Start time of the vesting period
    uint256 private immutable _start;
    
    // Duration of the vesting period in seconds (24 months after cliff)
    uint256 private immutable _duration;
    
    // Total amount of tokens to be vested
    uint256 private immutable _totalAmount;
    
    // Amount of token already released
    uint256 private _released;
    
    // Whether vesting is revocable
    bool private immutable _revocable;
    
    // Whether vesting has been revoked
    bool private _revoked;
    
    // Amount vested at the time of revocation
    uint256 private _revokedVestedAmount;

    /**
     * @dev Creates a vesting contract that vests its balance of any ERC20 token to the
     * beneficiary, gradually in a linear fashion until start + duration. By then all
     * of the balance will have vested.
     * @param beneficiary_ address of the beneficiary to whom vested tokens are transferred
     * @param token_ address of the ERC20 token contract
     * @param totalAmount_ total amount of tokens to be vested (1,000,000 tokens)
     * @param revocable_ whether the vesting is revocable or not
     */
    constructor(
        address beneficiary_,
        address token_,
        uint256 totalAmount_,
        bool revocable_
    ) Ownable(_msgSender()) {
        require(beneficiary_ != address(0), "TokenVesting: beneficiary is the zero address");
        require(token_ != address(0), "TokenVesting: token is the zero address");
        require(totalAmount_ > 0, "TokenVesting: total amount is 0");

        _beneficiary = beneficiary_;
        _token = IERC20(token_);
        _totalAmount = totalAmount_;
        _revocable = revocable_;
        _start = block.timestamp;
        _cliff = _start + 365 days; // 12 months cliff
        _duration = 730 days; // 24 months linear vesting after cliff
    }

    /**
     * @return the beneficiary of the tokens.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @return the token being vested.
     */
    function token() public view returns (IERC20) {
        return _token;
    }

    /**
     * @return the cliff time of the token vesting.
     */
    function cliff() public view returns (uint256) {
        return _cliff;
    }

    /**
     * @return the start time of the token vesting.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @return the duration of the token vesting.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @return the total amount of tokens to be vested.
     */
    function totalAmount() public view returns (uint256) {
        return _totalAmount;
    }

    /**
     * @return the amount of the token released.
     */
    function released() public view returns (uint256) {
        return _released;
    }

    /**
     * @return true if the vesting is revocable.
     */
    function revocable() public view returns (bool) {
        return _revocable;
    }

    /**
     * @return true if the vesting has been revoked.
     */
    function revoked() public view returns (bool) {
        return _revoked;
    }

    /**
     * @notice Transfers vested tokens to beneficiary.
     */
    function release() public {
        uint256 unreleased = _releasableAmount();
        require(unreleased > 0, "TokenVesting: no tokens are due");

        _released = _released + unreleased;

        _token.safeTransfer(_beneficiary, unreleased);

        emit TokensReleased(address(_token), unreleased);
    }

    /**
     * @notice Allows the owner to revoke the vesting. Tokens already vested
     * remain in the contract, the rest are returned to the owner.
     */
    function revoke() public onlyOwner {
        require(_revocable, "TokenVesting: cannot revoke");
        require(!_revoked, "TokenVesting: token already revoked");

        uint256 balance = _token.balanceOf(address(this));
        uint256 vestedAmt = _vestedAmount();
        uint256 refund = balance - vestedAmt;

        _revokedVestedAmount = vestedAmt;
        _revoked = true;

        if (refund > 0) {
            _token.safeTransfer(owner(), refund);
        }

        emit TokenVestingRevoked(address(_token));
    }

    /**
     * @dev Calculates the amount that has already vested but hasn't been released yet.
     */
    function _releasableAmount() private view returns (uint256) {
        return _vestedAmount() - _released;
    }

    /**
     * @dev Calculates the amount that has already vested.
     */
    function _vestedAmount() private view returns (uint256) {
        if (_revoked) {
            return _revokedVestedAmount;
        } else if (block.timestamp < _cliff) {
            return 0;
        } else if (block.timestamp >= _cliff + _duration) {
            return _totalAmount;
        } else {
            // Linear vesting after cliff
            uint256 timeFromCliff = block.timestamp - _cliff;
            return (_totalAmount * timeFromCliff) / _duration;
        }
    }

    /**
     * @notice Returns the amount of tokens that can be released at the current time.
     */
    function releasableAmount() public view returns (uint256) {
        return _releasableAmount();
    }

    /**
     * @notice Returns the amount of tokens that have been vested.
     */
    function vestedAmount() public view returns (uint256) {
        return _vestedAmount();
    }
}