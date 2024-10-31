# Decentralized Options Trading Platform

A secure and flexible smart contract platform for trading call and put options on the Stacks blockchain. This platform enables users to write, buy, and exercise options contracts using SIP-010 compliant tokens as collateral.

## Features

- Write and trade both CALL and PUT options
- SIP-010 token support with whitelisting
- Built-in price oracle integration
- Collateral management system
- Position tracking for writers and holders
- Protocol fee management
- Comprehensive error handling and input validation

## Contract Overview

### Core Functionality

- **Option Writing**: Create new options contracts by locking collateral
- **Option Trading**: Buy existing options by paying the premium
- **Option Exercise**: Exercise options before expiry if conditions are favorable
- **Position Management**: Track written and held options for each user
- **Price Feeds**: Oracle integration for accurate price data
- **Protocol Governance**: Fee management and token whitelisting

### Security Features

- Comprehensive input validation
- Protected admin functions
- Collateral requirement checks
- Critical token/symbol protection
- Expiry validation
- Authorization checks

## Technical Details

### Data Structures

#### Option Contract

```clarity
{
    writer: principal,
    holder: (optional principal),
    collateral-amount: uint,
    strike-price: uint,
    premium: uint,
    expiry: uint,
    is-exercised: bool,
    option-type: (string-ascii 4),  // "CALL" or "PUT"
    state: (string-ascii 9)         // Current state of the option
}
```

#### User Position

```clarity
{
    written-options: (list 10 uint),
    held-options: (list 10 uint),
    total-collateral-locked: uint
}
```

### Error Codes

| Code | Description             |
| ---- | ----------------------- |
| 1000 | Not authorized          |
| 1001 | Insufficient balance    |
| 1002 | Invalid expiry          |
| 1003 | Invalid strike price    |
| 1004 | Option not found        |
| 1005 | Option expired          |
| 1006 | Insufficient collateral |
| 1007 | Already exercised       |
| 1008 | Invalid premium         |
| 1009 | Invalid token           |
| 1010 | Invalid symbol          |
| 1011 | Invalid timestamp       |
| 1012 | Invalid address         |
| 1013 | Zero address            |
| 1014 | Empty symbol            |

## Usage

### Writing an Option

```clarity
(write-option
    token              ;; SIP-010 token used as collateral
    collateral-amount  ;; Amount of collateral to lock
    strike-price      ;; Strike price of the option
    premium           ;; Premium charged for the option
    expiry            ;; Block height at which option expires
    option-type)      ;; "CALL" or "PUT"
```

### Buying an Option

```clarity
(buy-option
    token      ;; SIP-010 token for premium payment
    option-id) ;; ID of the option to purchase
```

### Exercising an Option

```clarity
(exercise-option
    token      ;; SIP-010 token for settlement
    option-id) ;; ID of the option to exercise
```

## Administrative Functions

### Protocol Management

- `set-protocol-fee-rate`: Update the protocol fee rate
- `set-approved-token`: Whitelist or remove tokens
- `set-allowed-symbol`: Manage allowed price feed symbols
- `update-price-feed`: Update price data for supported trading pairs

### Security Considerations

1. **Collateral Management**

   - Collateral is locked in the contract
   - Automatic collateral return after exercise
   - Protected against unauthorized withdrawals

2. **Price Feed Security**

   - Only owner can update price feeds
   - Timestamp validation
   - Symbol whitelist

3. **Token Safety**
   - SIP-010 compliance requirement
   - Token whitelist
   - Critical token protection

## Development and Testing

### Prerequisites

- Clarity CLI
- Stacks blockchain node (optional for testing)
- SIP-010 compliant tokens for testing

### Deployment Checklist

1. Deploy contract
2. Set initial protocol fee rate
3. Whitelist accepted tokens
4. Configure allowed price feed symbols
5. Set up initial price feeds

## Limitations

- Maximum of 10 options per user position list
- Only supports SIP-010 compliant tokens
- Price feeds must be manually updated by contract owner
- Options cannot be cancelled once written
- No partial exercise functionality

## Future Improvements

1. Secondary market for options trading
2. Automated price feed updates
3. Partial exercise functionality
4. Option cancellation mechanism
5. Dynamic collateral requirements
6. Multi-asset options
7. American vs European option types

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
