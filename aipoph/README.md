# aipoph

The smart contract implementation for `aipoph`.

# First Pass Implementation

- the system starts from a contract that anyone can use to create many daos
- pure threshold-based dao using an already existing and distributed token
- the dao datum is a general type similar to cip68 metadatum
- an oracle for randomness must exist
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
