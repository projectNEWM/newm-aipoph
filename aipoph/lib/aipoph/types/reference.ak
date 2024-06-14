//// The Reference data types for `aipoph`
////

use aiken/builtin
use aiken/transaction/value.{Value}
use assist/types/hashes.{PublicKeyHash, ValidatorHash}

// general dict data type for the data requried for aipoph
pub type ReferenceDatum =
  Pairs<ByteArray, Data>

/// Find a data structure by some key inside the ReferenceDatum if the data
/// structure is found then return just the data else fail.
///
/// ```aiken
/// reference.find_data(this_datum, contract_key)
/// ```
pub fn find_data(data: ReferenceDatum, key: ByteArray) -> Data {
  when data is {
    [] -> fail @"Data Structure Not Found"
    [d, ..ds] ->
      if builtin.fst_pair(d) == key {
        builtin.snd_pair(d)
      } else {
        find_data(ds, key)
      }
  }
}

// The threshold structure is a data structure in ReferenceData
pub type Thresholds =
  Pairs<ByteArray, Int>

/// Find an action token threshold by some key inside the Thresholds data
/// structure. If a threshold is found then return the integer value else fail.
///
/// ```aiken
/// reference.find_threshold(these_thresholds, start_test_threshold_key)
/// ```
pub fn find_threshold(thresholds: Thresholds, key: ByteArray) -> Int {
  when thresholds is {
    [] -> fail @"Threshold Not Found"
    [d, ..ds] ->
      if builtin.fst_pair(d) == key {
        builtin.snd_pair(d)
      } else {
        find_threshold(ds, key)
      }
  }
}

// The contract structure is a data structure in ReferenceData
pub type Contracts =
  Pairs<ByteArray, ValidatorHash>

/// Find a contract validator hash by some key inside the Contracts data
/// structure. If a contract is found then return the validator hash else fail.
///
/// ```aiken
/// reference.find_contract(these_contracts, oracle_contract_key)
/// ```
pub fn find_contract(contracts: Contracts, key: ByteArray) -> ValidatorHash {
  when contracts is {
    [] -> fail @"Contract Not Found"
    [d, ..ds] ->
      if builtin.fst_pair(d) == key {
        builtin.snd_pair(d)
      } else {
        find_contract(ds, key)
      }
  }
}

// The fee structure is a data structure in ReferenceData
pub type Fees =
  Pairs<ByteArray, Int>

/// Find a maximum fee bound for some redeemer by some key inside the Fee data
/// structure. If a fee is found then return the integer value else fail.
///
/// ```aiken
/// reference.find_fee(these_fees, start_test_fee_key)
/// ```
pub fn find_fee(fees: Fees, key: ByteArray) -> Int {
  when fees is {
    [] -> fail @"Fee Not Found"
    [d, ..ds] ->
      if builtin.fst_pair(d) == key {
        builtin.snd_pair(d)
      } else {
        find_fee(ds, key)
      }
  }
}

/// Check that the transaction fee is less than or equal to the maximum allowed
/// fee for that redeemer. This prevents fee drain attacks by making sure a
/// transaction does not exceed the maximum allowed gas cost.
pub fn is_valid_fee(this_fee_value: Value, max_fee: Int) -> Bool {
  let this_fee: Int =
    value.quantity_of(this_fee_value, value.ada_policy_id, value.ada_asset_name)
  this_fee <= max_fee
}

// The keys structure is a data structure in ReferenceData
pub type Keys =
  Pairs<ByteArray, PublicKeyHash>

/// Find a public key hash by some key inside the Keys data structure. If a key
/// is found then return the public key hash else fail.
///
/// ```aiken
/// reference.find_key(these_keys, website_pkh_key)
/// ```
pub fn find_key(keys: Keys, key: ByteArray) -> PublicKeyHash {
  when keys is {
    [] -> fail @"Public Key Hash Not Found"
    [d, ..ds] ->
      if builtin.fst_pair(d) == key {
        builtin.snd_pair(d)
      } else {
        find_key(ds, key)
      }
  }
}
