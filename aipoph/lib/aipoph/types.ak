//// Constants and general data types for `aipoph`.
////

use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script, VerificationKey}

// Constants

// dRep Contribution Token
pub const drep_token_name: ByteArray =
  #"6452657020436f6e747269627574696f6e20546f6b656e"

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

pub type OwnerInfo {
  pkh: PublicKeyHash,
  sc: PublicKeyHash,
}
