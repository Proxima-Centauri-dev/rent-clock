# Rent Clock - Rental Payment Automation Smart Contract

A time-locked smart contract for automated rental payments built on the Stacks blockchain using Clarity. This contract enables trustless rental agreements with automated payment releases based on predetermined schedules.

## 🏠 Overview

Rent Clock eliminates the need for manual rent payments by creating automated, time-locked rental agreements. Tenants can deposit funds in advance, and payments are automatically released to landlords when due, creating a trustless rental payment system.

## ✨ Key Features

- **Automated Payments**: Time-locked payment releases based on block height
- **Trustless System**: Anyone can trigger payments when they're due
- **Flexible Terms**: Configurable rent amounts, payment intervals, and durations
- **Secure Fund Management**: Safe deposit and withdrawal mechanisms
- **Multi-party Support**: Multiple rental agreements per contract
- **Transparent Tracking**: Full payment history and balance visibility

## 🔧 Contract Functions

### Public Functions

#### `create-rental`
Creates a new rental agreement between tenant and landlord.

```clarity
(create-rental 
  (landlord principal)
  (monthly-rent uint)
  (deposit uint)
  (duration-blocks uint)
  (payment-interval uint))
```

**Parameters:**
- `landlord`: Principal address of the landlord
- `monthly-rent`: Rent amount in microSTX (1 STX = 1,000,000 microSTX)
- `deposit`: Security deposit amount in microSTX
- `duration-blocks`: Total rental period in blocks (~10 min per block)
- `payment-interval`: Blocks between payments (e.g., 4320 blocks ≈ 30 days)

**Returns:** `(ok rental-id)` or error

#### `deposit-funds`
Allows tenants to deposit STX tokens for future rent payments.

```clarity
(deposit-funds (rental-id uint) (amount uint))
```

#### `execute-payment`
Triggers rent payment when due (callable by anyone).

```clarity
(execute-payment (rental-id uint))
```

#### `withdraw-funds`
Allows tenants to withdraw unused funds.

```clarity
(withdraw-funds (rental-id uint) (amount uint))
```

#### `end-rental`
Terminates rental agreement (tenant or landlord only).

```clarity
(end-rental (rental-id uint))
```

### Read-Only Functions

#### `get-rental`
Returns complete rental agreement details.

```clarity
(get-rental (rental-id uint))
```

#### `get-rental-balance`
Returns current balance for a rental.

```clarity
(get-rental-balance (rental-id uint))
```

#### `is-payment-due`
Checks if payment can be executed.

```clarity
(is-payment-due (rental-id uint))
```

#### `get-next-payment-block`
Returns the block height when next payment is due.

```clarity
(get-next-payment-block (rental-id uint))
```

#### `is-rental-expired`
Checks if rental period has ended.

```clarity
(is-rental-expired (rental-id uint))
```

## 📋 Usage Example

### 1. Create Rental Agreement

```clarity
;; Create a 6-month rental for 1000 STX/month, paid every 30 days
(create-rental 
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7  ;; landlord
  u1000000000  ;; 1000 STX monthly rent
  u2000000000  ;; 2000 STX deposit
  u25920       ;; ~6 months in blocks
  u4320)       ;; ~30 days payment interval
```

### 2. Deposit Funds

```clarity
;; Tenant deposits 6000 STX to cover 6 months of rent
(deposit-funds u1 u6000000000)
```

### 3. Automated Payments

```clarity
;; Anyone can trigger payment when due
(execute-payment u1)
```

## 🔒 Security Features

- **Authorization Checks**: Only authorized parties can perform sensitive operations
- **Balance Validation**: Prevents overdrafts and invalid transfers
- **Time Locks**: Payments only execute when actually due
- **Error Handling**: Comprehensive error codes for different failure scenarios
- **State Validation**: Ensures rental is active before operations

## 🚨 Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| 100 | `ERR_NOT_AUTHORIZED` | Caller not authorized for operation |
| 101 | `ERR_RENTAL_NOT_FOUND` | Rental ID does not exist |
| 102 | `ERR_INSUFFICIENT_FUNDS` | Not enough balance for operation |
| 103 | `ERR_PAYMENT_NOT_DUE` | Payment cannot be executed yet |
| 104 | `ERR_RENTAL_INACTIVE` | Rental agreement is terminated |
| 105 | `ERR_INVALID_AMOUNT` | Amount must be greater than zero |

## ⏰ Time Calculations

The Stacks blockchain produces blocks approximately every 10 minutes. Use these conversions:

- **1 hour** ≈ 6 blocks
- **1 day** ≈ 144 blocks  
- **1 week** ≈ 1,008 blocks
- **1 month** ≈ 4,320 blocks
- **1 year** ≈ 52,560 blocks

## 🛠 Development Setup

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
```bash
git clone <repository-url>
cd rent-clock
```

2. Check contract syntax
```bash
clarinet check
```

3. Run tests
```bash
clarinet test
```

### Testing

The contract includes comprehensive error handling. Test scenarios should cover:

- Valid rental creation and payment execution
- Edge cases (expired rentals, insufficient funds)
- Authorization failures
- Invalid parameters

## 📊 Gas Considerations

- **Contract Deployment**: ~50,000 gas
- **Create Rental**: ~10,000 gas
- **Execute Payment**: ~15,000 gas
- **Deposit/Withdraw**: ~8,000 gas
