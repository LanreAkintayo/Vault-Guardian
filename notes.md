Let me try to understand how the vault works before going to the VaultGuardian base contract.
I guess vault guardian is a contract and guardian is just a user guarding the vault


When update() function or the mint() function is called in ERC20, totalSupply will increase.

Initially, the total supply of vault() / erc4626 is zero initially.

If the decimal offset is not updated to a value more than zero, then attacker can front-run the transaction.





If a user wants to become a token guardian (let's say weth)
There is a stake price that you have to pay. Currently the stake price is 10 weth (asset of the vault -> 1 vault per asset) 
10 weth will be sent to the vault and then the corresponding amount of shares will be minted to the user. 0.1% of the shares go to the guardian (the user) and 0.1% of the share goes to the vaultGuardianBase.sol contract

investFunds()
To become a token guardian, you pay say 10 weth.
During the process,
Let's say 25% of the 10 weth 2.5 weth will be for uniswap
Let's say 25% of the 10 weth 2.5 weth will be for aave




I'm trying to create a weth vault (weth guardian)
Guardian is the caller of the becomeGuardian() function.
vault guardian is the contract VaultGuardiansBase.sol


































