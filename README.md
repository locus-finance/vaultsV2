# vaultsV2

## VAULT
```
npx hardhat --network optimism deploy --tags Vault - deploy
npx hardhat --network optimism upgrade --target-contract Vault --target-addr VAULT_ADDRESS - upgrade
```

## STRATEGY

```
npx hardhat --network polygon deploy --tags PearlStrategy
npx hardhat --network polygon upgrade --target-contract PearlStrategy --target-addr STRATEGY_ADDRESS
```