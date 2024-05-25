//// The DAO data types for `aipoph`
////

use aiken/builtin
use aiken/transaction/value.{Value}
use assist/types/hashes.{PublicKeyHash, ValidatorHash}

// Petition may change the required lovelace on the utxo
pub type Petition {
  lovelace: Int,
}

// general dict data type for the data requried for aipoph
pub type DAODatum =
  Pairs<ByteArray, Data>

// find a data structure by a title inside the DAODatum data dictionary.
pub fn find_data(data: DAODatum, key: ByteArray) -> Data {
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

// The threshold structure is a data structure in DAOData
pub type Thresholds =
  Pairs<ByteArray, Int>

// find a threshold by some key inside the thresholds dictionary.
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

// The contract structure is a data structure in DAOData
pub type Contracts =
  Pairs<ByteArray, ValidatorHash>

// find a contract by title inside the contract dictionary.
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

pub fn delete_contract(
  contracts: Contracts,
  elem: ValidatorHash,
  holder: List<ValidatorHash>,
) -> List<ValidatorHash> {
  when contracts is {
    [] -> holder
    [x, ..xs] ->
      if builtin.snd_pair(x) == elem {
        delete_contract(xs, elem, holder)
      } else {
        delete_contract(xs, elem, [builtin.snd_pair(x), ..holder])
      }
  }
}

// The fee structure is a data structure in DAOData
pub type Fees =
  Pairs<ByteArray, Int>

// find a fee by title inside the fee dictionary.
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

pub fn is_valid_fee(this_fee: Value, fee: Int) -> Bool {
  let lovelace: Int =
    value.quantity_of(this_fee, value.ada_policy_id, value.ada_asset_name)
  fee > lovelace
}

// The contract structure is a data structure in DAOData
pub type Keys =
  Pairs<ByteArray, PublicKeyHash>

// find a contract by title inside the contract dictionary.
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
