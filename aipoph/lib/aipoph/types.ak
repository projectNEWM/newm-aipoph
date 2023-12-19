//// Constants and general data types for `aipoph`.
////

use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script, VerificationKey}

// Constants

// _aipoph_
pub const prefix: ByteArray = #"5f6169706f70685f"

// Congratulations! You're a human.
pub const certificate_of_humanity: ByteArray =
  #"436f6e67726174756c6174696f6e732120596f7527726520612068756d616e2e"

// General Types

pub type PublicKeyHash =
  Hash<Blake2b_224, VerificationKey>

// script hash
pub type ValidatorHash =
  Hash<Blake2b_224, Script>
