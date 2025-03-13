# Resonance Finance

**Resonance Finance** is a cutting-edge decentralized finance platform that allows employees to stake their Resonance Tokens **(RES)** or Ethereum **(ETH)** to earn rewards. To enhance the utility and liquidity of RES Tokens, Resonance Finance has introduced a liquidity pool that allows employees to seamlessly exchange RES tokens with USDC and vice versa. This liquidity pool is managed by the **ResPool** smart contract, which guarantees efficient and secure token exchanges while staking and rewards are managed by the **stakingProtocol** contract. This contract also implements a DAO governance to allow employees themselves to decide the staking time and minimum amounts of RES token used in the protocol.

## The Staking Protocol

At the heart of Resonance Finance is the Staking Protocol, a smart contract that will be deployed on the Ethereum blockchain. This contract allows employees to stake their RES tokens or native ETH and earn rewards over a specified staking duration. The staking process is simple:

- **Stake RES.** Users call the stake function, specifying the amount of RES they wish to stake. The contract transfers the specified amount of RES from the user's wallet to the contract and mints a unique NFT representing the staking position.

- **Stake ETH.** Users call the stakeWithETH function and send the desired amount of ETH. The contract mints a unique NFT representing the staking position.

- **Earn Rewards.** The staked RES tokens or ETH earn rewards over time. The reward rate is set at 5% of the staked amount.

- **Unstake.** After the staking duration is complete, users can call the unstake function to withdraw their staked tokens along with the earned rewards. The contract transfers the original amount and the rewards back to the user's wallet and burns the NFT representing the staking position.

## The DAO Governance

Resonance Finance empowers its employees through a DAO governance system, enabling them to propose and vote on changes to the staking parameters.

- **Create Proposals.** Users holding RES tokens can create proposals to change the staking parameters, such as the staking duration and the required staking amount.

- **Vote on Proposals.** Users can vote on active proposals. Each user's voting power is proportional to their RES holdings.

- **Execute Proposals.** Once a proposal receives enough votes, it is executed, and the staking parameters are updated accordingly.

## The Liquidity Pool

The ResPool smart contract is designed to facilitate the exchange of RES and USDC tokens. The pool operates with a constant product formula, ensuring that the invariant **(k = xy)** holds, where **x** and **y** are the reserves of RES and USDC respectively.

- **Swapping Tokens.** Users can swap RES for USDC or USDC for RES using the swapOutToIn function of the ResPool contract. The process is straightforward: Users specify the amount of tokenOut they want to receive and if its RES token or not. The contract calculates the required amount of tokenIn to be sent based on the current reserves and a 1% fee. The user sends the amount in to the contract, and the contract transfers the amount out to the user's wallet.

- **Providing Liquidity.** Liquidity providers can deposit tokens into the pool. The contract updates the user's balance and the pool's reserves.

- **Withdraw Tokens.** Users can withdraw their deposited tokens by calling the withdraw function, specifying the amounts of RES and USDC to withdraw. The contract transfers the tokens back to the user's wallet. Additionally, employees can withdraw all their deposited tokens at once by calling the withdrawAll function. The contract transfers the entire balance of RES and USDC back to the user's wallet.