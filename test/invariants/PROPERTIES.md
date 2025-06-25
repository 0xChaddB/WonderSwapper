# SwapperMVP Properties

## Invariants

### INV-1: Conservation of Value
- The sum of all user deposits should equal `totalDeposited`
- `∑ deposits[user] == totalDeposited`

### INV-2: State Consistency
- If `hasSwapped == false`, no withdrawals should have occurred
- If `hasSwapped == true`, no new deposits can be made

### INV-3: Token Conservation
- Before swap: `fromToken.balanceOf(swapper) >= totalDeposited`
- After swap: `toToken.balanceOf(swapper) >= totalDeposited` (assuming 1:1 ratio)

### INV-4: User Balance Integrity
- A user can never withdraw more than they deposited
- `withdrawn[user] <= deposits[user]`

### INV-5: No Token Creation
- The contract cannot create tokens out of thin air
- Total withdrawn <= Total available toToken balance

## Properties

### PROP-1: Deposit Monotonicity
- User deposits can only increase before swap
- `deposits[user]_after >= deposits[user]_before` (when hasSwapped == false)

### PROP-2: Withdrawal Finality
- Once a user withdraws, their deposit balance becomes 0
- After withdrawal: `deposits[user] == 0`

### PROP-3: Swap Irreversibility
- Once `hasSwapped` becomes true, it can never become false again
- `hasSwapped` transitions: false → true (never true → false)

### PROP-4: Access Control
- Any user can deposit (before swap)
- Any user can trigger swap
- Only users with deposits > 0 can withdraw (after swap)

### PROP-5: Time Independence
- The contract has no time-based logic
- All operations depend only on state, not block.timestamp