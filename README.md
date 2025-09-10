# M0 Protocol - Sui Implementation

A Sui Move port of the M0 Protocol, an immutable EVM protocol that enables minting and burning of the $M token with continuous yield distribution to approved earners. This implementation translates the core economic model to Sui's object-oriented paradigm while maintaining protocol safety and functionality.

## Overview

The M0 Protocol is a yield-bearing token system with three main actor types:
- **Minters**: Can mint and burn $M tokens (currently dummy implementation)
- **Validators**: Validate and manage protocol parameters (not implemented)
- **Yield Earners**: Approved accounts that earn continuous interest on their token holdings

The Sui implementation maintains two account types:
- **Earning accounts**: Accrue interest continuously based on their principal balance
- **Non-earning accounts**: Hold tokens at face value without interest accrual

## Repository Structure

```
protocol_sui/
├── sources/
│   ├── m_token.move              # Core $M token implementation
│   ├── minter_gateway.move       # Dummy minter management (not implemented)
│   ├── ttg_registrar.move        # Configuration registry (dummy implementation)
│   ├── continuous_indexing.move  # Mathematical foundation for interest calculations
│   ├── rate_models/
│   │   └── earner_rate_model.move # Dynamic rate calculation
│   └── libs/                     # Mathematical utilities
├── tests/                        # Comprehensive test suite
└── Move.toml                     # Project configuration
```

## Core Modules

### 1. MToken (`sources/m_token.move`)

The main $M token implementation with comprehensive functionality:

- **Dual Balance System**: Tracks both present value (face value) and principal amounts for earning accounts
- **Continuous Indexing**: Uses mathematical models for precise interest calculations over time  
- **Capability-based Access**: MinterCap for controlled mint/burn operations
- **Transfer Integration**: Seamless transfers between earning and non-earning accounts with automatic interest claiming
- **Interest Management**: Calculate and claim accrued interest separately from token balances

### 2. Continuous Indexing (`sources/continuous_indexing.move`)

Mathematical foundation providing:
- **Index Calculations**: Continuous compounding math for interest accrual
- **Rate Conversion**: Basis point to exponential rate conversions
- **Principal/Present Conversions**: Balance calculations between face value and underlying principal

### 3. TTG Registrar (`sources/ttg_registrar.move`)

Configuration management system (dummy implementation):
- **Parameter Storage**: Max earner rates, base minter rates
- **Governance Integration**: Placeholder for future TTG governance
- **Rate Limits**: Configurable safety parameters

### 4. MinterGateway (`sources/minter_gateway.move`)

Minter management system (dummy implementation):
- **Rate Tracking**: Current minter rates for protocol calculations
- **Supply Monitoring**: Total active owed M for rate model calculations
- **Future Integration**: Placeholder for full minter management

### 5. Earner Rate Model (`sources/rate_models/earner_rate_model.move`)

Dynamic rate calculation engine:
- **Safety Calculations**: Ensures protocol cash flow safety over time
- **Rate Limits**: Enforces maximum earner rates from TTG configuration
- **Complex Math**: Natural logarithm calculations for safety margins

## Key API Functions

### Core Token Operations
```move
// Mint new tokens (requires MinterCap)
public fun mint(protocol: &mut MTokenProtocol, cap: &MinterCap, account: address, amount: u256, ctx: &mut TxContext): Coin<M_TOKEN>

// Burn existing tokens (requires MinterCap)  
public fun burn(protocol: &mut MTokenProtocol, cap: &MinterCap, coin: Coin<M_TOKEN>, ctx: &TxContext): u256
```

### Earning State Management
```move
// Start earning interest on tokens
public fun start_earning(protocol: &mut MTokenProtocol, account: address, amount: u64, ctx: &mut TxContext)

// Stop earning and withdraw (returns amount and principal)
public fun stop_earning(protocol: &mut MTokenProtocol, account: address, ctx: &mut TxContext): (u64, u128)
```

### Interest Operations
```move
// Calculate accrued interest without claiming
public fun calculate_accrued_interest(protocol: &MTokenState, account: address, ctx: &TxContext): u256

// Claim accumulated interest
public fun claim_interest(protocol: &mut MTokenProtocol, account: address, ctx: &TxContext): u256

// Transfer with automatic interest claiming
public fun transfer_with_claim(protocol: &mut MTokenProtocol, coin: Coin<M_TOKEN>, recipient: address, amount: u64, ctx: &TxContext): (Coin<M_TOKEN>, u256, u256)
```

### Rate Model Integration
```move
// Update protocol interest rates (external integration)
public fun update_index_with_external_rate(protocol: &mut MTokenProtocol, rate: u32, ctx: &TxContext)
```

## Design Changes: Solidity EVM → Move Sui VM

### 1. **Token Representation Paradigm**

**Solidity (EVM)**:
```solidity
mapping(address => uint256) private _balances;
function balanceOf(address account) public view returns (uint256)
```

**Move (Sui VM)**:
```move
// Uses native Coin<T> objects instead of balance mappings
public fun mint(...): coin::Coin<M_TOKEN>
// Balance queries happen through Sui's native coin system
```

**Why**: Sui's object model treats tokens as first-class objects that can be transferred, combined, and split directly. This eliminates the need for ERC20-style balance mappings.

### 2. **Access Control Pattern**

**Solidity (EVM)**:
```solidity
modifier onlyMinterGateway() {
    require(msg.sender == minterGateway, "Unauthorized");
    _;
}
```

**Move (Sui VM)**:
```move
public struct MinterCap has key, store { id: UID }
public fun mint(protocol: &mut MTokenProtocol, _cap: &MinterCap, ...)
```

**Why**: Move uses capability-based security where possession of a capability object grants access rights. This is more flexible than address-based access control and integrates better with Sui's ownership model.

### 3. **State Management Architecture**

**Solidity (EVM)**:
```solidity
// Global contract state
mapping(address => bool) public isEarning;
mapping(address => uint128) public principalOfTotalEarningSupply;
```

**Move (Sui VM)**:
```move
public struct MTokenState has store {
    earning_accounts: Table<address, EarningAccount>,
    total_non_earning_supply: u64,
    continuous_indexing: ContinuousIndexing,
    // ...
}
```

**Why**: Sui's object model encourages explicit state organization. Instead of implicit global mappings, state is explicitly structured in objects that can be shared, transferred, or kept private.

### 4. **Rebasing vs Non-Rebasing Tokens**

**Solidity (EVM)**:
```solidity
// Rebasing: balanceOf() returns present value that changes over time
function balanceOf(address account) public view returns (uint256) {
    return isEarning[account] ? presentAmount : staticAmount;
}
```

**Move (Sui VM)**:
```move
// Non-rebasing: Coin values are static, interest claimed separately
// Avoids breaking external integrations (wallets, indexers, DEXs)
public fun claim_interest(...): u256 // Explicit interest claiming
```

**Why**: Rebasing breaks compatibility with Sui wallets, indexers, and DeFi protocols that expect stable coin values. The Move implementation separates principal (coin value) from interest (claimed separately).

### 5. **External Integration Pattern**

**Solidity (EVM)**:
```solidity
function rate() external view returns (uint256) {
    return IEarnerRateModel(earnerRateModel).rate();
}
```

**Move (Sui VM)**:
```move
// Avoids circular dependencies through external rate injection
public fun update_index_with_external_rate(protocol: &mut MTokenProtocol, rate: u32, ctx: &TxContext)
```

**Why**: Move's module system is stricter about circular dependencies. Instead of direct cross-module calls, we use dependency injection patterns where external systems provide calculated rates.

### 6. **Event and Error Handling**

**Solidity (EVM)**:
```solidity
error InsufficientBalance(address account);
emit Transfer(from, to, amount);
```

**Move (Sui VM)**:
```move
// Uses Sui's native error handling and event system
assert!(balance >= amount, EInsufficientBalance);
// Events emitted through Sui's native event system
```

**Why**: We use abort codes instead of custom errors, and has a built-in event system that integrates with Sui's transaction processing.

## Key Architectural Benefits

1. **Composability**: Native coin integration allows seamless interaction with other Sui protocols
2. **Security**: Capability-based access control provides fine-grained permission management
3. **Performance**: Object-based state management reduces global state contention
4. **Compatibility**: Non-rebasing design maintains compatibility with external systems
5. **Transparency**: Explicit state structure makes protocol behavior more predictable

## Testing

Run the comprehensive test suite:

```bash
sui move test protocol_sui::m_token_test
```

The test suite covers:
- MinterCap functionality and access control
- Interest accrual and claiming mechanisms  
- Balance conversions between earning/non-earning states
- Transfer operations with automatic interest claiming
- Rate model integration and index updates
- Error conditions and edge cases

## Implementation Status

### ✅ Fully Implemented
- **Core M Token**: Complete token functionality with earning/non-earning state management
- **Mathematical Foundation**: Continuous indexing and rate calculations
- **Interest System**: Accrual, claiming, and distribution mechanisms
- **Access Control**: Capability-based security with MinterCap
- **Transfer System**: Seamless transfers with automatic interest handling
- **Test Suite**: 35 comprehensive tests covering all functionality

### ⚠️ Placeholder/Dummy Implementations
- **MinterGateway**: Basic structure for rate/supply queries (intentionally left as dummy)
- **TTG Registrar**: Configuration storage with dummy governance integration
- **Validator System**: Not implemented (not part of current scope)

### 🚧 Integration Patterns
- **Rate Model Integration**: Uses external dependency injection to avoid circular dependencies
- **Cross-module Communication**: Designed for future integration with full protocol suite

## Development Setup

### Prerequisites
- [Sui CLI](https://docs.sui.io/build/install) for compilation and testing
- Move language support for your IDE

### Build and Test
```bash
# Compile the Move modules
sui move build

# Run all tests
sui move test

# Run specific module tests  
sui move test protocol_sui::m_token_test

# Check for compilation warnings
sui move build --skip-fetch-latest-git-deps
```

### Project Configuration
The project uses standard Sui Move project structure with dependencies defined in `Move.toml`:
- **Sui Framework**: Core Sui Move standard library
- **Integer Mate**: Mathematical utilities for signed integers
- **External Libraries**: Additional mathematical and utility functions

## Original Protocol Reference

This Sui implementation is based on the original EVM-compatible M0 Protocol:
- **Repository**: [M0 Protocol Solidity](https://github.com/m0-foundation/protocol)  
- **Core Contract**: `protocol/src/MToken.sol`
- **Architecture**: See original protocol documentation for economic model details

The Sui version maintains the same economic guarantees and behavior while adapting to Sui's object model and leveraging Move's safety features. Key architectural differences are documented in the "Design Changes" section above.