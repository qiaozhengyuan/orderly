
# Test Case List

### Initialization
1. **Initialize Contract with Valid Tokens**: Test that the contract can be initialized with a valid set of token addresses (at least two tokens).
2. **Initialize Contract with Single Token**: Ensure the contract reverts when initialized with only one token.
3. **Initialize Contract with Multiple Ether Tokens**: Ensure the contract reverts if more than one Ether (address 0) token is provided.
4. **Ensure Admin Role is Assigned**: After initialization, check that the deployer has both `DEFAULT_ADMIN_ROLE` and `ADMIN_ROLE`.

### Pausing and Unpausing
5. **Pause the Contract by Admin**: Test that the admin can pause the contract.
6. **Unpause the Contract by Admin**: Test that the admin can unpause the contract.
7. **Pause the Contract by Non-Admin**: Ensure that a non-admin address cannot pause the contract.
8. **Unpause the Contract by Non-Admin**: Ensure that a non-admin address cannot unpause the contract.

### Adding Liquidity
9. **Add Initial Liquidity with Valid Amounts**: Test adding liquidity with the correct amounts for each supported token.
10. **Add Initial Liquidity with Zero Amounts**: Ensure the contract reverts when attempting to add liquidity with zero token amounts.
11. **Add Liquidity with Amount Mismatch**: Ensure the contract reverts if the number of token amounts provided does not match the number of supported tokens.
12. **Add Liquidity Proportionally to Reserves**: Test adding liquidity in proportion to the existing reserves and validate liquidity tokens are minted.
13. **Add Liquidity When Contract is Paused**: Ensure adding liquidity fails when the contract is paused.

### Removing Liquidity
14. **Remove Liquidity with Valid Amount**: Test removing liquidity and receiving the correct proportion of tokens back.
15. **Remove Liquidity with Zero Amount**: Ensure the contract reverts when attempting to remove zero liquidity.
16. **Remove Liquidity Exceeding User Balance**: Ensure the contract reverts when a user tries to remove more liquidity than they have.
17. **Remove Liquidity When Contract is Paused**: Ensure removing liquidity fails when the contract is paused.

### Token Swapping
18. **Swap Tokens with Valid Parameters**: Test swapping tokens when the reserves are sufficient, and the output token amount meets the minimum requirement.
19. **Swap Tokens with Zero AmountIn**: Ensure the contract reverts if the input amount for a swap is zero.
20. **Swap Between the Same Token**: Ensure the contract reverts if trying to swap a token for itself.
21. **Swap When Insufficient Liquidity for Output**: Ensure the contract reverts if the contract cannot provide enough liquidity for the requested output.
22. **Swap When Output Amount is Less Than Minimum**: Ensure the contract reverts if the output amount is less than the specified minimum amount.
23. **Swap When Contract is Paused**: Ensure swapping tokens fails when the contract is paused.

### Withdrawing Fees
24. **Withdraw Fees with Available Fees**: Test withdrawing fees by an admin when there is a balance greater than the reserves for a token.
25. **Withdraw Fees When No Fees Available**: Ensure the contract reverts when trying to withdraw fees for a token that does not have a balance greater than the reserves.
26. **Withdraw Fees by Non-Admin**: Ensure that non-admin addresses cannot withdraw fees.

### Reserves and Liquidity Calculation
27. **Calculate Required Amounts for Liquidity**: Test the `getRequiredAmounts` function to ensure it returns the correct amounts for the given reference token amount.
28. **Calculate Initial Liquidity Using Geometric Mean**: Ensure that the initial liquidity is calculated correctly using the geometric mean when first adding liquidity.
