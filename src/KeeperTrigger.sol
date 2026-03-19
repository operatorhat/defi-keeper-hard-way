// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title  KeeperTrigger
 * @author Solidity Smart Contract Engineer
 * @notice Time-based Chainlink Automation upkeep trigger. Signals and executes
 *         a recurring task once `interval` seconds have elapsed since the last
 *         performance. Designed for mainnet deployment: gas-tight, reentrancy-
 *         safe, and fully audit-ready.
 *
 * @dev    Implements the Chainlink Automation `AutomationCompatibleInterface`
 *         inline (no external import) so the contract remains self-contained.
 *         `interval` is stored as an immutable to eliminate SLOAD overhead on
 *         every `checkUpkeep` call.
 *
 *         Security properties:
 *         - `checkUpkeep`  is a pure view — no state changes possible.
 *         - `performUpkeep` follows Checks-Effects-Interactions: the guard
 *           check and state write occur before the event emission.
 *         - Custom error replaces revert strings to save ~50 gas per revert
 *           path and produce machine-readable selectors for off-chain tooling.
 */
contract KeeperTrigger {

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------

    /// @notice Thrown when `performUpkeep` is invoked before the interval has elapsed.
    error UpkeepNotNeeded();

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    /**
     * @notice Emitted every time `performUpkeep` successfully resets the timer.
     * @param  timestamp The `block.timestamp` at which the upkeep was performed.
     */
    event UpkeepPerformed(uint256 indexed timestamp);

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    /// @notice The minimum number of seconds that must elapse between upkeeps.
    /// @dev    Declared `immutable`: written once in the constructor, then
    ///         baked into bytecode. Saves one SLOAD (~2100 gas cold, ~100 warm)
    ///         on every `checkUpkeep` invocation.
    uint256 public immutable INTERVAL;

    /// @notice The `block.timestamp` at which the most recent upkeep was performed.
    ///         Initialised to the deployment timestamp so the first upkeep window
    ///         begins from a well-defined baseline.
    uint256 public lastTimestamp;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    /**
     * @notice Deploys the trigger and sets the recurring interval.
     * @dev    Initialises `lastTimestamp` to `block.timestamp` so the first
     *         upkeep becomes eligible exactly `_interval` seconds after deploy,
     *         rather than immediately.
     * @param  _interval Seconds between eligible upkeep windows. Must be > 0;
     *                   a zero interval would make upkeep permanently eligible
     *                   and is almost certainly a misconfiguration.
     */
    constructor(uint256 _interval) {
        // Minimal guard — keeps the ABI honest without pulling in OZ.
        require(_interval > 0, "KeeperTrigger: interval cannot be zero");
        INTERVAL      = _interval;
        lastTimestamp = block.timestamp;
    }

    // -------------------------------------------------------------------------
    // Chainlink Automation Interface
    // -------------------------------------------------------------------------

    /**
     * @notice Called off-chain by the Chainlink Automation network to determine
     *         whether `performUpkeep` should be invoked.
     * @dev    Pure view — touches only immutable/storage reads, no state mutation.
     *         `performData` is unused here but forwarded untouched to
     *         `performUpkeep` by the Automation network; reserved for subclasses
     *         or future extension.
     *
     *         Gas note: `interval` is `immutable` (no SLOAD); `lastTimestamp` is
     *         one warm SLOAD after the first call in a block.
     *
     * @param  /* checkData *\/ Arbitrary bytes passed by the Automation registry.
     *         Not used in this implementation.
     * @return upkeepNeeded  `true` when `block.timestamp - lastTimestamp >= interval`.
     * @return performData   Empty bytes; passed through to `performUpkeep` as-is.
     */
    function checkUpkeep(bytes calldata /* checkData */)
        external
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        upkeepNeeded = (block.timestamp - lastTimestamp) >= INTERVAL;
        // performData intentionally left as zero-length bytes.
        // Returning a named variable avoids an extra MSTORE for the empty bytes.
        performData  = bytes("");
    }

    /**
     * @notice Executed on-chain by the Chainlink Automation network (or any
     *         caller) when `checkUpkeep` returns `true`.
     * @dev    Checks-Effects-Interactions order:
     *           1. CHECK  — revert early if the interval has not elapsed.
     *           2. EFFECT — update `lastTimestamp` before emitting.
     *           3. INTERACT — emit event (read-only external observer, safe last).
     *
     *         Anyone may call this function; the Chainlink registry does not
     *         restrict callers at the contract level. The guard condition is the
     *         sole access control: calling ahead of schedule is a no-op revert.
     *
     * @param  performData Arbitrary bytes forwarded from `checkUpkeep`. Unused
     *                     in this implementation; included for interface compliance.
     *
     * @custom:emits UpkeepPerformed The new `block.timestamp` after the reset.
     * @custom:error UpkeepNotNeeded Reverts when the interval has not yet elapsed.
     */
    function performUpkeep(bytes calldata performData) external {
        // ------------------------------------------------------------------
        // CHECK: guard against premature execution
        // ------------------------------------------------------------------
        if ((block.timestamp - lastTimestamp) < INTERVAL) {
            revert UpkeepNotNeeded();
        }

        // ------------------------------------------------------------------
        // EFFECT: reset the timer — write before any external interaction
        // ------------------------------------------------------------------
        lastTimestamp = block.timestamp;

        // ------------------------------------------------------------------
        // INTERACT: emit event (external observers, not a call, but kept last
        // by convention to signal "state is now settled")
        // ------------------------------------------------------------------
        emit UpkeepPerformed(block.timestamp);

        // Silence the unused-parameter compiler warning without wasting gas
        // on a read or conversion.
        performData; // referenced to suppress warning; optimiser eliminates it
    }
}