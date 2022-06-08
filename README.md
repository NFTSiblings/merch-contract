This is the repo we used for the NFT Siblings Anniversary Merch drop.

A few things to note about this particular project:
- Token metadata folder was added. This folder is not a part of Hardhat, but we added this to store the metadata for the NFTs.
- Minters of these NFTs had the opportunity to pay in $ASH. For this reason we have included a TestERC20.sol file in the contracts directory for testing.
- We have included a beta and a production version of our NFT contract in the contracts directory. This is not a requirement of Hardhat.
- We have made a few changes to the smart contract for the sake of testing. For example, the payoutAddress variable is set to public so that we can test it's setter function. We have made notes next to all of these changes in the smart contract so that they are not accidentally deployed in the production version.
- I have commented out the network parameter from the module.exports in hardhat.config.js. This code is necessary for deploying contracts to rinkeby with the deploy.js script. You should include that code with your own private key if you want to deploy to rinkeby through hardhat.

Some advanced Hardhat techniques which were used in this project:
- In the beforeEach object in our test script, we used a loop to create 100 more wallets than Hardhat gives us by default
- We use the ethers.BigNumber.from() command to parse large numbers in our test script