// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

// @title Voting Escrow Locus
// @author Curve Finance | Translation to Solidity - Locus Team
// @license MIT
// @notice Votes have a weight depending on time, so that users are
//         committed to the future of (whatever they are voting for)
// @dev Vote weight decays linearly over time. Lock time cannot be
//     more than `MAXTIME` (2 years).
contract VotingEscrow is ReentrancyGuard, Ownable2Step {
    using SafeERC20 for IERC20Metadata;

    // # Voting escrow to have time-weighted votes
    // # Votes have a weight depending on time, so that users are committed
    // # to the future of (whatever they are voting for).
    // # The weight in this implementation is linear, and lock cannot be more than maxtime:
    // # w ^
    // # 1 +        /
    // #   |      /
    // #   |    /
    // #   |  /
    // #   |/
    // # 0 +--------+------> time
    // #       maxtime (2 years?)

    error MaxTimeHit();
    error CannotLockZero();
    error CannotAddToLockWithZeroBalance();
    error LockHasNotYetBeenCreated();
    error LockExpired();
    error CannotCreateLockInPastTime();
    error CannotCreateLockForLessThenMinLock();
    error CanOnlyModifyLockDuration();
    error LockHasToBeExpired();
    error CanOnlyLookIntoPastBlocks();

    struct Point {
        int128 bias;
        int128 slope; // - dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
        uint256 start;
    }

    event Deposit(
        address indexed provider,
        uint256 value,
        uint256 indexed locktime,
        int128 _type,
        uint256 ts
    );
    event Withdraw(address indexed provider, uint256 value, uint256 ts);
    event Supply(uint256 prevSupply, uint256 supply);

    int128 public constant DEPOSIT_FOR_TYPE = 0;
    int128 public constant CREATE_LOCK_TYPE = 1;
    int128 public constant INCREASE_LOCK_AMOUNT = 2;
    int128 public constant INCREASE_UNLOCK_TIME = 3;

    // General constants
    uint256 public constant YEAR = 4 weeks * 12;
    uint256 public constant MAXTIME = YEAR * 2;
    uint256 public constant MULTIPLIER = 10 ether;

    uint256 public supply;

    mapping(address => LockedBalance) public locked;

    uint256 public epoch;
    mapping(uint256 => Point) public pointHistory; // epoch -> unsigned point /*Point[100000000000000000000000000000]*/

    // Point[1000000000]
    mapping(address => mapping(uint256 => Point)) public userPointHistory; // user -> Point[user_epoch]

    mapping(address => uint256) public userPointEpoch;
    mapping(uint256 => int128) public slopeChanges; // time -> signed slope change

    uint8 public immutable decimals;
    string public constant name = "Voting Escrow Locus Token";
    string public constant symbol = "veLCS";

    uint256 public minLockDuration;

    // """
    // @notice Contract constructor
    // @param token_addr `ERC20CRV` token address
    // @param _name Token name
    // @param _symbol Token symbol
    // """
    constructor(address tokenAddr, uint256 _minLockDuration) {
        pointHistory[0].blk = block.number;
        pointHistory[0].ts = block.timestamp;
        decimals = IERC20Metadata(tokenAddr).decimals();
        _setMinLockDuration(_minLockDuration);
    }

    function _setMinLockDuration(uint256 _minLockDuration) private {
        if (_minLockDuration >= MAXTIME) revert MaxTimeHit();
        minLockDuration = _minLockDuration;
    }

    function setMinLockDuration(uint256 _minLockDuration) external onlyOwner {
        _setMinLockDuration(_minLockDuration);
    }

    // """
    // @notice Get the most recently recorded rate of voting power decrease for `addr`
    // @param addr Address of the user wallet
    // @return Value of the slope
    // """
    function getLastUserSlope(address addr) external view returns (int128) {
        uint256 uepoch = userPointEpoch[addr];
        return userPointHistory[addr][uepoch].slope;
    }

    // """
    // @notice Get the timestamp for checkpoint `_idx` for `_addr`
    // @param _addr User wallet address
    // @param _idx User epoch number
    // @return Epoch time of the checkpoint
    // """
    function userPointHistoryTs(
        address addr,
        uint256 idx
    ) external view returns (uint256) {
        return userPointHistory[addr][idx].ts;
    }

    // """
    // @notice Record global and per-user data to checkpoint
    // @param addr User's wallet address. No user checkpoint if 0x0
    // @param old_locked Pevious locked amount / end lock time for the user
    // @param new_locked New locked amount / end lock time for the user
    // """
    function _checkpoint(
        address addr,
        LockedBalance memory oldLocked,
        LockedBalance memory newLocked
    ) internal {
        Point memory uOld;
        Point memory uNew;
        int128 oldDSlope = 0;
        int128 newDSlope = 0;
        // uint256 _epoch = epoch;

        int128 signedMaxTime = SafeCast.toInt128(SafeCast.toInt256(MAXTIME));

        if (addr != address(0)) {
            // # Calculate slopes and biases
            // # Kept at zero when they have to
            if (
                oldLocked.end > block.timestamp && oldLocked.amount > int128(0)
            ) {
                uOld.slope = oldLocked.amount / signedMaxTime;
                uOld.bias =
                    uOld.slope *
                    SafeCast.toInt128(
                        SafeCast.toInt256(oldLocked.end - block.timestamp)
                    );
            }
            if (newLocked.end > block.timestamp && newLocked.amount > 0) {
                uNew.slope = newLocked.amount / signedMaxTime;
                uNew.bias =
                    uNew.slope *
                    SafeCast.toInt128(
                        SafeCast.toInt256(newLocked.end - block.timestamp)
                    );
            }

            // # Read values of scheduled changes in the slope
            // # old_locked.end can be in the past and in the future
            // # new_locked.end can ONLY by in the FUTURE unless everything expired: than zeros
            oldDSlope = slopeChanges[oldLocked.end];
            if (newLocked.end != 0) {
                if (newLocked.end == oldLocked.end) {
                    newDSlope = oldDSlope;
                } else {
                    newDSlope = slopeChanges[newLocked.end];
                }
            }
        }
        Point memory lastPoint = Point({
            bias: 0,
            slope: 0,
            ts: block.timestamp,
            blk: block.number
        });
        if (epoch > 0 /*_epoch*/) {
            lastPoint = pointHistory[epoch /*_epoch*/];
        }
        // uint256 lastCheckpoint = lastPoint.ts;

        // # initial_last_point is used for extrapolation to calculate block number
        // # (approximately, for *At methods) and save them
        // # as we cannot figure that out exactly from inside the contract

        Point memory initialLastPoint = lastPoint;
        uint256 blockSlope = 0;
        if (block.timestamp > lastPoint.ts) {
            blockSlope =
                (MULTIPLIER * (block.number - lastPoint.blk)) /
                (block.timestamp - lastPoint.ts);
        }

        // # If last point is already recorded in this block, slope=0
        // # But that's ok b/c we know the block in such case
        //
        // # Go over weeks to fill history and calculate what the current point is
        uint256 tI = (lastPoint.ts / 1 weeks) * 1 weeks; /*lastCheckpoint*/

        for (uint256 i = 0; i < 255; i++) {
            // # Hopefully it won't happen that this won't get used in 5 years!
            // # If it does, users will be able to withdraw but vote weight will be broken
            tI += 1 weeks;
            int128 dSlope = 0;

            if (tI > block.timestamp) {
                tI = block.timestamp;
            } else {
                dSlope = slopeChanges[tI];
            }

            lastPoint.bias -=
                lastPoint.slope *
                SafeCast.toInt128(
                    SafeCast.toInt256(tI - lastPoint.ts /*lastCheckpoint*/)
                );

            lastPoint.slope += dSlope;

            if (lastPoint.bias < 0) {
                // # This can happen
                lastPoint.bias = 0;
            }

            if (lastPoint.slope < 0) {
                // # This cannot happen - just in case
                lastPoint.slope = 0;
            }

            // lastCheckpoint = tI;
            lastPoint.ts = tI;
            lastPoint.blk =
                initialLastPoint.blk +
                (blockSlope * (tI - initialLastPoint.ts)) /
                MULTIPLIER;
            epoch += 1; /*_epoch*/

            if (tI == block.timestamp) {
                lastPoint.blk = block.number;
                break;
            } else {
                pointHistory[epoch /*_epoch*/] = lastPoint;
            }
        }

        // epoch = _epoch;
        // # Now point_history is filled until t=now

        if (addr != address(0)) {
            // # If last point was in this block, the slope change has been applied already
            // # But in such case we have 0 slope(s)
            lastPoint.slope += (uNew.slope - uOld.slope);
            lastPoint.bias += (uNew.bias - uOld.bias);
            if (lastPoint.slope < 0) {
                lastPoint.slope = 0;
            }
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
        }

        // # Record the changed point into history
        pointHistory[epoch /*_epoch*/] = lastPoint;

        if (addr != address(0)) {
            // # Schedule the slope changes (slope is going down)
            // # We subtract new_user_slope from [new_locked.end]
            // # and add old_user_slope to [old_locked.end]
            if (oldLocked.end > block.timestamp) {
                // # old_dslope was <something> - u_old.slope, so we cancel that
                oldDSlope += uOld.slope;
                if (newLocked.end == oldLocked.end) {
                    oldDSlope -= uNew.slope;
                }
                slopeChanges[oldLocked.end] = oldDSlope;
            }
            if (newLocked.end > block.timestamp) {
                if (newLocked.end > oldLocked.end) {
                    newDSlope -= uNew.slope;
                    slopeChanges[newLocked.end] = newDSlope;
                }
                // else: we recorded it already in old_dslope
            }

            // Now handle user history
            // uint256 userEpoch = userPointEpoch[addr] + 1;

            userPointEpoch[addr] += 1; //= userPointEpoch[addr] + 1/*userEpoch*/;
            uNew.ts = block.timestamp;
            uNew.blk = block.number;
            userPointHistory[addr][userPointEpoch[addr] /*userEpoch*/] = uNew;
        }
    }

    // """
    // @notice Deposit and lock tokens for a user
    // @param _addr User's wallet address
    // @param _value Amount to deposit
    // @param unlock_time New time when to unlock the tokens, or 0 if unchanged
    // @param locked_balance Previous locked amount / timestamp
    // """
    function _depositFor(
        address _addr,
        uint256 _value,
        uint256 unlockTime,
        LockedBalance storage lockedBalance,
        int128 _type
    ) internal {
        uint256 supplyBefore = supply;

        supply = supplyBefore + _value;
        LockedBalance memory oldLocked = lockedBalance;
        // # Adding to existing lock, or if a lock is expired - creating a new one

        lockedBalance.amount += SafeCast.toInt128(SafeCast.toInt256(_value));
        if (unlockTime != 0) {
            lockedBalance.end = unlockTime;
        }
        locked[_addr] = lockedBalance;

        // # Possibilities:
        // # Both old_locked.end could be current or expired (>/< block.timestamp)
        // # value == 0 (extend lock) or value > 0 (add to lock or extend lock)
        // # _locked.end > block.timestamp (always)
        _checkpoint(_addr, oldLocked, lockedBalance);

        emit Deposit(_addr, _value, lockedBalance.end, _type, block.timestamp);
        emit Supply(supplyBefore, supplyBefore + _value);
    }

    // """
    // @notice Record global data to checkpoint
    // """
    function checkpoint() external {
        LockedBalance memory _emptyBalance;
        _checkpoint(address(0), _emptyBalance, _emptyBalance);
    }

    // """
    // @notice Deposit `_value` tokens for `_addr` and add to the lock
    // @dev Anyone (even a smart contract) can deposit for someone else, but
    //      cannot extend their locktime and deposit for a brand new user
    // @param _addr User's wallet address
    // @param _value Amount to add to user's lock
    // """
    function depositFor(address _addr, uint256 _value) external nonReentrant {
        LockedBalance storage _locked = locked[_addr];
        if (_value == 0) revert CannotLockZero();
        if (_locked.amount == 0) revert CannotAddToLockWithZeroBalance();
        if (_locked.end <= block.timestamp) revert LockExpired();
        _depositFor(_addr, _value, 0, _locked, DEPOSIT_FOR_TYPE);
    }

    // """
    // @notice Deposit `_value` tokens for `msg.sender` and lock until `_unlock_time`
    // @param _value Amount to deposit
    // @param _unlock_time Epoch time when tokens unlock, rounded down to whole weeks
    // """
    function createLock(
        uint256 _value,
        uint256 _unlockTime
    ) external nonReentrant {
        _createLockFor(msg.sender, _value, _unlockTime);
    }

    function _createLockFor(
        address _for,
        uint256 _value,
        uint256 _unlockTime
    ) internal {
        uint256 unlockTime = (_unlockTime / 1 weeks) * 1 weeks; // # Locktime is rounded down to weeks
        LockedBalance storage _locked = locked[_for];

        if (_value == 0) revert CannotLockZero();
        if (_locked.amount > 0) revert LockHasNotYetBeenCreated();
        if (unlockTime <= block.timestamp) revert CannotCreateLockInPastTime();
        if (unlockTime < minLockDuration + block.timestamp)
            revert CannotCreateLockForLessThenMinLock();
        if (unlockTime > block.timestamp + MAXTIME) revert MaxTimeHit();

        _locked.start = block.timestamp;

        _depositFor(_for, _value, unlockTime, _locked, CREATE_LOCK_TYPE);
    }

    function createLockFor(
        address _for,
        uint256 _value,
        uint256 _unlockTime
    ) external nonReentrant {
        _createLockFor(_for, _value, _unlockTime);
    }

    // """
    // @notice Deposit `_value` additional tokens for `msg.sender`
    //         without modifying the unlock time
    // @param _value Amount of tokens to deposit and add to the lock
    // """
    function increaseAmount(uint256 _value) external nonReentrant {
        LockedBalance storage _locked = locked[msg.sender];
        if (_value == 0) revert CannotLockZero();
        if (_locked.amount == 0) revert CannotAddToLockWithZeroBalance();
        if (_locked.end <= block.timestamp) revert LockExpired();
        _depositFor(msg.sender, _value, 0, _locked, INCREASE_LOCK_AMOUNT);
    }

    // """
    // @notice Extend the unlock time for `msg.sender` to `_unlock_time`
    // @param _unlock_time New epoch time for unlocking
    // """
    function increaseUnlockTime(uint256 _unlockTime) external nonReentrant {
        LockedBalance storage _locked = locked[msg.sender];
        uint256 unlockTimeNearestWeek = (_unlockTime / 1 weeks) * 1 weeks; // Locktime is rounded down to weeks

        if (_locked.end <= block.timestamp) revert LockExpired();
        if (_locked.amount == 0) revert CannotAddToLockWithZeroBalance();
        if (unlockTimeNearestWeek <= _locked.end)
            revert CanOnlyModifyLockDuration();
        if (unlockTimeNearestWeek > block.timestamp + MAXTIME)
            revert MaxTimeHit();

        _depositFor(
            msg.sender,
            0,
            unlockTimeNearestWeek,
            _locked,
            INCREASE_UNLOCK_TIME
        );
    }

    // """
    // @notice Withdraw all tokens for `msg.sender`
    // @dev Only possible if the lock has expired
    // """
    function withdraw() external nonReentrant {
        LockedBalance storage _locked = locked[msg.sender];
        if (block.timestamp < _locked.end) revert LockHasToBeExpired();
        // Upcasting is done without checks because the downcasting was with safe checks.
        uint256 value = uint128(_locked.amount);

        LockedBalance memory oldLocked = _locked;
        _locked.end = 0;
        _locked.amount = 0;
        locked[msg.sender] = _locked;
        uint256 supplyBefore = supply;
        supply = supplyBefore - value;

        // # old_locked can have either expired <= timestamp or zero end
        // # _locked has only 0 end
        // # Both can have >= 0 amount
        _checkpoint(msg.sender, oldLocked, _locked);

        emit Withdraw(msg.sender, value, block.timestamp);
        emit Supply(supplyBefore, supplyBefore - value);
    }

    // """
    // @notice Binary search to estimate timestamp for block number
    // @param _block Block to find
    // @param max_epoch Don't go beyond this epoch
    // @return Approximate timestamp for block
    // """
    function findBlockEpoch(
        uint256 _block,
        uint256 maxEpoch
    ) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = maxEpoch;
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (pointHistory[_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }
        return _min;
    }

    // """
    // @notice Get the current voting power for `msg.sender`
    // @dev Adheres to the IERC20Metadata `balanceOf` interface for Aragon compatibility
    // @param addr User wallet address
    // @param _t Epoch time to return voting power at
    // @return User voting power
    // """
    function balanceOf(address addr) public view returns (uint256) {
        return balanceOf(addr, block.timestamp);
    }

    function balanceOf(address addr, uint256 _t) public view returns (uint256) {
        uint256 _epoch = userPointEpoch[addr];
        if (_epoch == 0) {
            return 0;
        } else {
            Point memory lastPoint = userPointHistory[addr][_epoch];
            lastPoint.bias -=
                lastPoint.slope *
                SafeCast.toInt128(SafeCast.toInt256(_t - lastPoint.ts));
            if (lastPoint.bias < 0) {
                lastPoint.bias = 0;
            }
            // Upcasting is performed without safe checks cause the downcasting was with them.
            return uint128(lastPoint.bias);
        }
    }

    // """
    // @notice Measure voting power of `addr` at block height `_block`
    // @dev Adheres to MiniMe `balanceOfAt` interface: https://github.com/Giveth/minime
    // @param addr User's wallet address
    // @param _block Block to calculate the voting power at
    // @return Voting power
    // """
    function balanceOfAt(
        address addr,
        uint256 _block
    ) external view returns (uint256) {
        // # Copying and pasting totalSupply code because Vyper cannot pass by
        // # reference yet
        if (_block > block.number) revert CanOnlyLookIntoPastBlocks();

        // Binary search
        uint256 _min = 0;
        uint256 _max = userPointEpoch[addr];
        for (uint256 i = 0; i < 128; i++) {
            if (_min >= _max) {
                break;
            }
            uint256 _mid = (_min + _max + 1) / 2;
            if (userPointHistory[addr][_mid].blk <= _block) {
                _min = _mid;
            } else {
                _max = _mid - 1;
            }
        }

        Point memory upoint = userPointHistory[addr][_min];

        uint256 maxEpoch = epoch;
        uint256 _epoch = findBlockEpoch(_block, maxEpoch);
        Point memory point0 = pointHistory[_epoch];
        uint256 dBlock = 0;
        uint256 dT = 0;
        if (_epoch < maxEpoch) {
            Point memory point1 = pointHistory[_epoch + 1];
            dBlock = point1.blk - point0.blk;
            dT = point1.ts - point0.ts;
        } else {
            dBlock = block.number - point0.blk;
            dT = block.timestamp - point0.ts;
        }
        uint256 blockTime = point0.ts;
        if (dBlock != 0) {
            blockTime += (dT * (_block - point0.blk)) / dBlock;
        }

        upoint.bias -=
            upoint.slope *
            SafeCast.toInt128(SafeCast.toInt256(blockTime - upoint.ts));
        if (upoint.bias >= 0) {
            // Upcasting is performed without safe checks because downcasting was performed with them.
            return uint128(upoint.bias);
        } else {
            return 0;
        }
    }

    // """
    // @notice Calculate total voting power at some point in the past
    // @param point The point (bias/slope) to start search from
    // @param t Time to calculate the total voting power at
    // @return Total voting power at that time
    // """
    function supplyAt(
        Point memory point,
        uint256 t
    ) internal view returns (uint256) {
        Point memory lastPoint = point;
        uint256 tI = (lastPoint.ts / 1 weeks) * 1 weeks;
        for (uint256 i = 0; i < 255; i++) {
            tI += 1 weeks;
            int128 dSlope = 0;
            if (tI > t) {
                tI = t;
            } else {
                dSlope = slopeChanges[tI];
            }
            lastPoint.bias -=
                lastPoint.slope *
                SafeCast.toInt128(SafeCast.toInt256(tI - lastPoint.ts));
            if (tI == t) {
                break;
            }
            lastPoint.slope += dSlope;
            lastPoint.ts = tI;
        }

        if (lastPoint.bias < 0) {
            lastPoint.bias = 0;
        }
        // Upcasting is performed without safety checks because the downcasting was with them.
        return uint128(lastPoint.bias);
    }

    // """
    // @notice Calculate total voting power
    // @dev Adheres to the IERC20Metadata `totalSupply` interface for Aragon compatibility
    // @return Total voting power
    // """
    function totalSupply() external view returns (uint256) {
        return totalSupply(block.timestamp);
    }

    // returns supply of locked tokens
    function lockedSupply() external view returns (uint256) {
        return supply;
    }

    function totalSupply(uint256 t) public view returns (uint256) {
        uint256 _epoch = epoch;
        Point memory lastPoint = pointHistory[_epoch];
        return supplyAt(lastPoint, t);
    }

    // """
    // @notice Calculate total voting power at some point in the past
    // @param _block Block to calculate the total voting power at
    // @return Total voting power at `_block`
    // """
    function totalSupplyAt(uint256 _block) external view returns (uint256) {
        if (_block > block.number) revert CanOnlyLookIntoPastBlocks();
        uint256 _epoch = epoch;
        uint256 targetEpoch = findBlockEpoch(_block, _epoch);

        Point memory point = pointHistory[targetEpoch];
        uint256 dt = 0; // difference in total voting power between _epoch and targetEpoch

        if (targetEpoch < _epoch) {
            Point memory pointNext = pointHistory[targetEpoch + 1];
            if (point.blk != pointNext.blk) {
                dt =
                    ((_block - point.blk) * (pointNext.ts - point.ts)) /
                    (pointNext.blk - point.blk);
            }
        } else {
            if (point.blk != block.number) {
                dt =
                    ((_block - point.blk) * (block.timestamp - point.ts)) /
                    (block.number - point.blk);
            }
        }

        // # Now dt contains info on how far are we beyond point
        return supplyAt(point, point.ts + dt);
    }
}
