## DYOFarm

DYOFarm is a permissionless protocol for deploying custom ERC20 staking pools on Ethereum mainnet.

DYOFarm addresses a sore need in defi - the ability for people to create custom staking pools for any ERC20. These staking pools, or "farms", have 4 properties: deposit token, reward token, start time and end time. Users must stake deposit token in the farm to earn reward token. Rewards are distributed linearly, pro rata in between start time and end time.

## Usage

### Contracts

The DYOFarm protocol consists of two main contracts:

1. `DYOFarm`: This contract represents a staking pool where users can stake deposit tokens and earn reward tokens.

2. `DYOFarmFactory`: This contract is responsible for deploying new instances of `DYOFarm` contracts.

Please refer to the contract source code for more details on the implementation.
