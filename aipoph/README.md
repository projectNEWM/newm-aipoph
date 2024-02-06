# aipoph

- TODO

This is the smart contract implementation for `aipoph`. We seek to create a novel method for certifying human identity in a decentralized and secure manner.

The current solution aims to create a system of contracts that are as close to a hyperstructure as possible. All federated and centralized solutions ought to be able to be derived from this solution.


## Implementation Strategy

There are many pieces to this puzzle. Each existing to fulfill a purpose within the ecosystem of the contracts.

### Genesis Contract

The system initiates with a genesis contract, accessible to any user wishing to start their own version of `aipoph`. This contract aims to be a trustless method for starting the ecosystem without the need for a trusted setup ceremony.

### DAO Contract

The DAO contract regulates all required data for the entire ecosystem. The DAO here is a lot less like a business and more like a on-chain database for the data required to run the Proof of Humanity ecosystem. It has a single action, petition, which allows the data to be updated as needed. The DAO is modeled as a pure threshold-based action-reaction system, utilizing an fairly distributed token. This allows anyone with enough of the DAO voting token to participate in the ecosystem. The DAO datum follows a general dictionary structure akin to the CIP68 metadatum, ensuring flexibility and adaptability. This design should allow for an infinitely updatable DAO without ever needing to restart the DAO with a new data structure.

### Oracle Contract

The oracle contract allows users with enough of the DAO token to generate random data for the Proof of Humanity system as it relies on a source of randomness to generate unique tests for the users. It has a single action and contains a random integer and bytearray.

### Vault Contract

The vault contract will be used to stored lost deposits for failed tests. Anyone can add funds to the vault but only a threshold actor can subtract any.

### Representative Contract

### Proof of Humanity Contract

### Certificate of Humanity Contract


### tldr

This should be a pretty good attempt at a hyperstructure proof of humanity using Aiken.

## Happy Path Scripts

Use the `complete_build.sh` script to build project.