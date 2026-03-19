# defi-keeper-hard-way

A minimal, gas-tight Chainlink Automation upkeep trigger built with Solidity and Foundry.

Built as part of my AI-native DeFi builder series — shipping real contracts, the hard way.

---

## What It Does

`KeeperTrigger` signals and executes a recurring on-chain task once a configurable
time interval has elapsed since the last performance. It implements the Chainlink
Automation interface inline (no external imports) to stay self-contained.

---

## Contract Overview

| Component | Description |
|---|---|
| `INTERVAL` | Immutable seconds between eligible upkeep windows. Set at deploy, baked into bytecode. |
| `lastTimestamp` | Tracks the last time `performUpkeep` ran. Initialized to `block.timestamp` on deploy. |
| `checkUpkeep()` | Returns `true` when `block.timestamp - lastTimestamp >= INTERVAL`. Pure view. |
| `performUpkeep()` | Resets the timer and emits `UpkeepPerformed`. Reverts early via custom error. |
| `UpkeepPerformed` | Indexed event emitted on every successful upkeep execution. |
| `UpkeepNotNeeded` | Custom error thrown when `performUpkeep` is called before the interval elapses. |

---

## Security Properties

- `checkUpkeep` is a pure view — no state changes possible
- `performUpkeep` follows Checks-Effects-Interactions order
- Custom error replaces revert strings (~50 gas saved per revert path)
- `INTERVAL` as `immutable` eliminates SLOAD overhead on every `checkUpkeep` call

---

## Run Locally

```bash
git clone https://github.com/operatorhat/defi-keeper-hard-way
cd defi-keeper-hard-way
forge install
forge test -vv
```

**15/15 tests passing.**

---

## Test Coverage

```
test_checkUpkeep_ReturnsFalse_BeforeInterval
test_checkUpkeep_ReturnsFalse_OneSecondShort
test_checkUpkeep_ReturnsTrue_AtExactInterval
test_checkUpkeep_ReturnsTrue_AfterInterval
test_checkUpkeep_ReturnsFalse_AfterSuccessfulPerform
test_performUpkeep_ResetsLastTimestamp
test_performUpkeep_EmitsUpkeepPerformed
test_performUpkeep_RevertsWhenNotNeeded_Immediate
test_performUpkeep_RevertsWhenNotNeeded_OneSecondShort
test_performUpkeep_SubsequentCallRevertsUntilNextInterval
test_performUpkeep_AnyCallerCanTrigger
test_performUpkeep_PerformDataParamIgnored
test_constructor_SetsImmutableInterval
test_constructor_SetsLastTimestampToDeployBlock
test_constructor_RevertsOnZeroInterval
```

---

## Built With

- Solidity `^0.8.24`
- [Foundry](https://book.getfoundry.sh/)
