# AIPoPh

**AIPoPh** introduces an innovative smart contract framework designed to verify human identities in a decentralized, secure way. Our solution pioneers a system that closely resembles a hyperstructure, serving as a foundational model from which both federated and centralized identity verification methods can be developed.

## Genesis Contract: Trustless Ecosystem Initiation

The `AIPoPh` system begins with a Genesis Contract, designed to enable any user to initiate their version of `AIPoPh` effortlessly. This foundational contract offers a trustless approach for launching the ecosystem, eliminating the necessity for a trusted setup ceremony.

## DAO Data Contract: On-Chain Database for Proof of Humanity

The DAO Data Contract serves as the central repository for all necessary data within the `AIPoPh` ecosystem. Unlike a traditional business-oriented DAO, this contract functions more as an on-chain database, pivotal for managing the Proof of Humanity ecosystem's data. It incorporates a singular action, `petition`, enabling timely updates to the data as required. The DAO is crafted as a threshold-based system, with a democratically distributed voting token that empowers any holder with sufficient tokens to contribute to the ecosystem. The structure of the DAO data mirrors the flexible, adaptable format of the CIP68 metadatum, promoting a model that is endlessly updatable without the need to overhaul the DAO's data structure. This ensures continuous evolution without restarting from scratch.

## Random Oracle Contract: Generating Randomness for Proof of Humanity

The Oracle Contract is integral to `AIPoPh`, enabling users who possess a sufficient amount of the DAO token to produce random data essential for the Proof of Humanity system. This system depends on a reliable source of randomness to create unique tests for users. The contract features a straightforward mechanism—a single action to update values, encompassing both a random integer and a bytearray. This design ensures the continuous generation of necessary randomness within the ecosystem.

## Vault Contract: Safeguarding Lost Deposits

The Vault Contract is designed to securely store lost deposits resulting from failed tests within the `AIPoPh` ecosystem. It permits open contributions, allowing anyone to add funds, yet restricts withdrawals exclusively to authorized entities that meet a predefined threshold. This approach ensures that funds are safeguarded and managed responsibly.

## Proof of Humanity Contract: Facilitating Human Verification Tests

The Proof of Humanity Contract is a pivotal component of the `AIPoPh` system, where a user initiates the verification process by depositing a UTXO. A trusted actor, holding a sufficient quantity of DAO tokens, sets the initial conditions for the test. The user then signs these conditions and submits the transaction, officially starting the PoH test. To complete the test, the user visits the designated website, signs in, and finishes the test. The website's actor, upon verifying the completed test, signs it off as finished. Subsequently, another authorized actor reviews the test results. If the test is deemed valid, a Certificate of Humanity is issued; otherwise, the user's deposit is transferred to the Vault Contract, ensuring integrity and accountability throughout the process.

## Certificate of Humanity Contract: Management of Verification Credentials

The Certificate of Humanity resides within its dedicated contract, which oversees the revocation and verification of existing certificates. Any certificate may be revoked by an authorized threshold actor at any time, resulting in the certificate's annulment and the redirection of associated funds to the Vault Contract. Verification of a certificate is perpetually available; any user can initiate the verification function, which reactivates the test's concluding verification step. External contracts might necessitate calling this function directly or referencing the certificate's UTXO, compelling the user to perform a signature verification to affirm rightful ownership and usage of the certificate.
