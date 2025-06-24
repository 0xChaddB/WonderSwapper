  1. What state variables the contract needs
   - Users addresses and amount, timelock timer
  2. What functions it should have
    - Has a fromToken and a toToken property that can be both set in the constructor.
    - Has a provide(amount) function that will take the amount of the fromToken from the function caller.
    - Has a swap function that will exchange all provided tokens into the toToken
    - Has a withdraw function that allows the user that provided the tokens to withdraw the toTokens that he should be allowed to withdraw.
  3. What security checks each function needs
    - check if enough time has passed
    - check if 