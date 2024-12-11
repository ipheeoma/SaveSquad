# SaveSquad Decentralized Savings Pool

## Overview

SaveSquad is a community-driven decentralized savings mechanism built on the Stacks blockchain. The smart contract enables a rotating savings pool where participants contribute monthly and take turns receiving the collective funds.

## Key Features

- **Participant Limit**: Restricts the number of participants to ensure pool manageability
- **Fixed Monthly Contributions**: Standardized contribution amount for all participants
- **Rotating Withdrawal System**: Pseudorandom selection of payout recipient each cycle
- **Transparent Governance**: Contract owner manages critical pool operations.

## Contract Workflow

### 1. Pool Initialization
- Contract owner sets:
  - Maximum number of participants
  - Monthly contribution amount

### 2. Participant Onboarding
- Users can join the pool if:
  - Total participants are below the limit
  - They are not already a participant

### 3. Monthly Contributions
- Active participants contribute a fixed monthly amount
- Contributions are pooled and tracked
- Each participant can contribute only once per cycle

### 4. Payout Recipient Selection
- Contract owner selects the next payout recipient
- Selection uses a pseudorandom mechanism based on cycle number
- Ensures fair distribution of funds

### 5. Withdrawal
- Selected recipient can withdraw the total pooled funds
- Each recipient can withdraw only once per cycle

## Smart Contract Functions

### Initialization
- `initialize-pool(max-participants, monthly-contribution)`
  - Sets up the savings pool parameters
  - Can only be called by contract owner

### Participant Management
- `join-pool()`
  - Allows a new participant to join the savings pool
  - Checks participant limit and existing membership

### Contribution
- `contribute()`
  - Participants deposit their monthly contribution
  - Validates contribution eligibility
  - Updates pool funds

### Payout Management
- `select-payout-recipient()`
  - Chooses the next recipient for fund withdrawal
  - Increments the current cycle
  - Can only be called by contract owner

- `withdraw-payout()`
  - Allows the selected recipient to withdraw pool funds
  - Validates withdrawal eligibility
  - Resets pool funds after withdrawal

## Read-Only Functions

- `get-participant-info(participant)`
  - Retrieves detailed information about a specific participant

- `get-pool-status()`
  - Provides an overview of the current pool state
  - Includes cycle, total funds, participant limit, and contribution amount

## Error Handling

The contract implements robust error handling with specific error codes:
- `ERROR-UNAUTHORIZED`: Prevents unauthorized actions
- `ERROR-ALREADY-PARTICIPANT`: Stops duplicate participation
- `ERROR-NOT-PARTICIPANT`: Ensures only pool members can perform actions
- `ERROR-INSUFFICIENT-FUNDS`: Prevents operations with insufficient pool resources
- `ERROR-INVALID-WITHDRAWAL`: Manages withdrawal constraints

## Use Cases

- **Community Savings**: Local groups can create collaborative savings mechanisms
- **Rotating Credit Associations**: Enables structured, transparent fund sharing
- **Financial Inclusion**: Provides a decentralized alternative to traditional savings models

## Security Considerations

- Only contract owner can initialize and manage critical pool operations
- Pseudorandom recipient selection ensures fairness
- Strict validation at each step prevents misuse

## Deployment Prerequisites

- Stacks blockchain environment
- Minimum STX balance for contract deployment and participant contributions

## Example Deployment Scenario

1. Contract owner deploys SaveSquad with:
   - 10 participant limit
   - 100 STX monthly contribution

2. Participants join and contribute monthly
3. Each cycle, a new participant is selected to receive funds
4. Funds are withdrawn, and the cycle continues

## Contributing

Contributions, bug reports, and feature requests are welcome. Please submit issues or pull requests on the project repository.
