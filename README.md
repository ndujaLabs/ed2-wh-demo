# ed2-wh-demo

Original tutorial: https://docs.openzeppelin.com/learn/developing-smart-contracts

```
npm install
npx hardhat compile
```

Deploy locally:
```
npx hardhat node
npx hardhat run --network localhost scripts/deploy.js
```

Interact:
```
npx hardhat console --network localhost
Welcome to Node.js v12.22.1.
Type ".help" for more information.
> const C = await ethers.getContractFactory('Everdragons2WormholeDemo')
undefined
> const c = await C.attach('0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9')
undefined
> await c.safeMint('0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', 10001)
...
> await c.tokenURI(10001)
...
```
