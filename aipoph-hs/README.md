# aipoph

This is the smart contract implementation for `aipoph`. We seek to create a novel method for certifying human identity in a decentralized and secure manner.

The current solution aims to create a system of contracts that are as close to a hyperstructure as possible. All federated and centralized solutions ought to be able to be derived from this solution.


## Implementation Strategy

There are many pieces to this puzzle.

### Genesis Contract

The system initiates with a genesis contract, accessible to any user wishing to start their own version of `aipoph`. This contract aims to be a trustless method for starting the ecosystem without the need for a trusted setup ceremony.

### DAO Contract

The DAO contract regulates all required data for the entire ecosystem. The DAO here is a lot less like a business and more like a on-chain database for the data required to run the Proof of Humanity ecosystem. It has a single action, petition, which allows the data to be updated as needed. The DAO is modeled as a pure threshold-based action-reaction system, utilizing an fairly distributed token. This allows anyone with enough of the DAO voting token to participate in the ecosystem. The DAO datum follows a general dictionary structure akin to the CIP68 metadatum, ensuring flexibility and adaptability. This design should allow for an infinitely updatable DAO without ever needing to restart the DAO with a new data structure.

### Oracle Contract

The oracle contract allows users with enough of the DAO token to generate random data for the Proof of Humanity system as it relies on a source of randomness to generate unique tests for the users. It has a single action and contains a random integer and bytearray.

### Vault Contract

The vault contract will be used to stored lost deposits for failed tests.

### Representative Contract

### Proof of Humanity Contract

### Certificate of Humanity Contract



# First Pass Implementation

- the system starts from a genesis contract that anyone can use
- pure threshold-based dao using an already existing and distributed token
- the dao datum is a general type similar to cip68 metadatum
- an oracle for randomness must exist
- distributed reps must exists to simply the transactions
- users interact with large holders of the token to start the process
- the process is timed
- users have an unlimited tries to attempt the solution until the time runs out
- have ability to do pure off chain secondary validations after initial test
- certificates of humanity live in a storage contract with inline datum
- verifications can be done with either a contract validations or valid signature
- contracts will initially be designed so the cryptographic proof generation system can be arbitrary
- end is goal is a happy path that demestrates the minting of a ceritificate of humanity using the proof of humanity protocol
- the certificate nft name should be "Congratulations! You're a human." its actually 32 characters

This should be an attempt at a hyperstructure proof of humanity using Aiken.

## Happy Path Scripts

Use the `complete_build.sh` script to build project.