# Micro-Freelancer Smart Contract

A Clarity smart contract for managing milestone-based freelance jobs on the Stacks blockchain.

## Features

- Create jobs with multiple milestones and budgets in STX
- Fund jobs by clients
- Submit milestone completions by freelancers
- Approve milestones and release funds by clients
- Cancel jobs before funding
- Simple on-chain state management

## Contract Functions

### Public Functions

- `create-job`: Create a new job with specified freelancer and milestone amounts
- `fund-job`: Fund an existing job with STX
- `submit-milestone`: Mark a milestone as completed by the freelancer
- `approve-milestone`: Approve and release payment for a submitted milestone
- `cancel-job`: Cancel an unfunded job

### Read-Only Functions

- `get-job`: Get job details by ID
- `get-milestone-status`: Get the status of a specific milestone

## Error Codes

- `ERR-UNAUTHORIZED (u100)`: Unauthorized access attempt
- `ERR-NOT-FOUND (u101)`: Job not found
- `ERR-ALREADY-FUNDED (u102)`: Job is already funded
- `ERR-NOT-FUNDED (u103)`: Job is not funded
- `ERR-NOT-MILESTONE (u104)`: Invalid milestone index
- `ERR-INVALID-AMOUNT (u105)`: Invalid amount specified
- `ERR-ALREADY-PAID (u106)`: Milestone already paid

## Security Notes

- Deploy on testnet first
- Thoroughly test STX transfers
- Contract uses basic safety checks for principal authorization
- Limited to simple milestone-based payments

## Limitations

- Requires exact budget funding in single transaction
- No built-in dispute resolution
- No partial refunds
- No timeout mechanisms
- Simple milestone approval flow

## License

[Add your license information here]
