# SaveSquad Decentralized Savings Pool

## Overview
SaveSquad is a decentralized savings pool smart contract implemented on the Stacks blockchain. The goal is to allow participants to pool contributions in various supported currencies and withdraw funds on a cyclic basis. The contract features referral rewards, token whitelisting, and improved type safety for better reliability.

## Key Features
- **Savings Pool:** Members can join and contribute to a savings pool, which is managed on a cycle-based system.
- **Referral Program:** Encourages participation by rewarding members who bring in new users.
- **Multi-Currency Support:** Allows contributions in different tokens, with on-the-fly conversion.
- **Type Safety:** Uses a custom fungible token trait and strong parameter validation.
- **Oracle Integration:** Enables dynamic pricing for token conversions.
- **Whitelisted Tokens:** Only approved tokens can be used within the contract.

## Error Codes
| Code | Description                         |
|------|-------------------------------------|
| `u1` | Not authorized                      |
| `u2` | Insufficient funds                  |
| `u3` | Already a member                    |
| `u4` | Not a member                        |
| `u5` | Cycle not complete                  |
| `u6` | Invalid withdrawal                  |
| `u7` | Invalid pool size                   |
| `u8` | Invalid contribution                |
| `u9` | Invalid currency                    |
| `u10`| Oracle error                        |
| `u11`| Referral not found                  |
| `u12`| Conversion failed                   |
| `u13`| Token contract not found            |
| `u14`| Invalid parameter                   |
| `u15`| Invalid token                       |

## Contract Constants
- `CONTRACT-OWNER`: The address of the contract owner.
- `ERR-*`: Predefined error codes.
- `referral-bonus-percentage`: Default 5% bonus for referrals.
- `max-referral-bonus`: Maximum bonus amount per referral, set to 100,000 microSTX.

## Storage Structures
### Pool Parameters
- `pool-size`: Number of members allowed in the pool.
- `contribution-amount`: Amount each member must contribute per cycle.
- `current-cycle`: Tracks the current contribution cycle.
- `total-pool-balance`: The total balance of the pool.
- `oracle-address`: Address of the price oracle.

### Supported Currencies
- Stored in `supported-currencies` map with:
  - `is-active`: Whether the currency is active.
  - `decimals`: Decimal precision of the token.
  - `min-amount`: Minimum contribution amount.
  - `price-multiplier`: Conversion factor.
  - `token-principal`: Token contract address.

### Members
- Stored in `members` map with:
  - `is-active`: Whether the member is active.
  - `total-contributions`: Total contributions by the member.
  - `last-contribution-cycle`: The last cycle when the member contributed.
  - `referrer`: Referring member.
  - `referral-count`: Number of referrals made by the member.
  - `bonus-balance`: Referral bonus balance.

### Cycle Withdrawals
- Stored in `cycle-withdrawals` map with:
  - `selected-member`: Member selected for withdrawal.
  - `is-withdrawn`: Whether the withdrawal has been processed.
  - `withdrawal-currency`: Currency used for withdrawal.

### Whitelisted Tokens
- `whitelisted-tokens`: Tracks approved tokens by principal.

## Core Functions
### Public Functions
1. **`initialize-pool(size uint, contribution uint)`**
   - Initializes the pool with a size and contribution amount.
   - Only callable by the contract owner.

2. **`set-oracle-address(new-oracle principal)`**
   - Updates the oracle address.
   - Only callable by the contract owner.

3. **`join-pool(referrer (optional principal))`**
   - Allows a user to join the pool with an optional referrer.

4. **`contribute-in-currency(currency (string-ascii 10), token <ft-trait>)`**
   - Contribute to the pool in the specified currency using a whitelisted token.

5. **`withdraw(token <ft-trait>)`**
   - Allows a selected member to withdraw pool funds at the end of a cycle.

### Private Functions
1. **`is-whitelisted-token(token-principal principal)`**
   - Checks if a token is whitelisted.

2. **`update-referrer-stats(referrer principal)`**
   - Updates referral statistics for a referring member.

3. **`calculate-referral-bonus()`**
   - Calculates the referral bonus for a contribution.

4. **`get-converted-amount(currency (string-ascii 10), amount uint)`**
   - Converts a given amount based on the currency's price multiplier.

### Read-Only Functions
1. **`get-member-info(member principal)`**
   - Fetches information about a member.

2. **`get-pool-status()`**
   - Provides the current pool status, including size, contributions, and balance.

3. **`get-currency-info(currency (string-ascii 10))`**
   - Returns information about a supported currency.

4. **`get-referral-program-info()`**
   - Returns details about the referral program.

5. **`is-token-whitelisted(token-principal principal)`**
   - Checks if a token is whitelisted.

## Deployment Instructions
1. Deploy the contract on the Stacks blockchain using a compatible Clarity IDE.
2. Initialize the pool using `initialize-pool` with desired size and contribution amount.
3. Configure supported currencies and whitelisted tokens.
4. Add an oracle address using `set-oracle-address`.

## Security Considerations
- Only authorized addresses can modify pool configurations.
- Contributions are validated using token whitelisting and price multipliers.
- Referral bonuses are capped to prevent abuse.

## Future Enhancements
- Dynamic cycle durations.
- Improved oracle integration for real-time token pricing.
- Support for non-fungible token rewards.
