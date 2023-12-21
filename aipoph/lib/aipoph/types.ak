//// Constants and general data types for `aipoph`.
////

use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction/credential.{Script, VerificationKey}
use aiken/transaction/value.{AssetName, PolicyId, Value}

// Constants

// dRep Contribution Token
pub const drep_token_name: AssetName =
  #"6452657020436f6e747269627574696f6e20546f6b656e"

// _aipoph_
pub const prefix: ByteArray = #"5f6169706f70685f"

// Congratulations! You're a human.
pub const coh_token_name: AssetName =
  #"436f6e67726174756c6174696f6e732120596f7527726520612068756d616e2e"

// Begin The Proof Of Humanity Test
pub const poh_token_name: AssetName =
  #"426567696e205468652050726f6f66204f662048756d616e6974792054657374"

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

pub type TokenInfo {
  pid: PolicyId,
  tkn: AssetName,
  amt: Int,
}

/// Convert a TokenInfo type into a Value type.
pub fn to_value(v: TokenInfo) -> Value {
  value.from_asset(v.pid, v.tkn, v.amt)
}
