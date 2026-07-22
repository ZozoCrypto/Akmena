# Implementation Guidelines

## File Header Template

Every Solidity file SHALL begin with:

```solidity
/**
 * @title ModuleName
 * @notice Short description
 *
 * Implements:
 * - Book:
 * - APS:
 * - RFC:
 * - ADR:
 * - Domain:
 * - Module:
 * - Service:
 * - Storage Namespace:
 * - Events:
 * - Tests:
 */
```

## Contract Rules

* One primary responsibility per contract.
* No hidden protocol state.
* No magic constants.
* No inline assembly unless justified by ADR.

## Interface Rules

Interfaces define protocol behavior.

Contracts implement interfaces.

Interfaces SHALL be versioned.

## Event Rules

Events SHALL represent completed state transitions only.

## Error Rules

Use custom errors.

Errors SHALL be deterministic and machine-readable.

## Dependency Rules

A module may depend only on lower protocol layers.

Circular dependencies are forbidden.
