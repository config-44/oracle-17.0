## oracle-17 example

This repository contains an example of a smart contract that sends a request
to the ORACLE-17 system and subsequently receives a response to that query.

## run example

1. install prerequirements

- `Node.js v18.16.0. or newer`
- `jq-1.6 or newer`
- `everdev`

2. install dependencies

```bash
yarn install
```

3. setup venom devnet network endpoints
```bash
export RPC=https://everspace.center/venom-devnet/jsonRpc
npx everdev n add devnet https://gql-devnet.venom.network/graphql
```

4. deploy `Example.sol` smart contract

Use Eye address from [`../README.md`](../README.md) insted of `$ADDRESS`
```bash
yarn deploy $ADDRESS
```
Then follow the instructions in your terminal

5. send request with smart contract
```bash
yarn request https://mainnet-v4.tonhubapi.com/block/30081623
```

6. read the result by calling the `get_last_result` method
```bash
printf "\n$(npx everdev c l -n devnet -a $(cat build/Example.addr.txt) build/Example.abi.json get_last_result | awk -v RS='' -F 'Execution has finished with result:\n' '{print $2}' | jq -r .output.value0)"
```