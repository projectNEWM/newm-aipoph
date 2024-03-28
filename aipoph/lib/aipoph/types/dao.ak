//// The DAO data types for `aipoph`
////

use aiken/transaction/value.{Value}
use assist/types/hashes.{PublicKeyHash, ValidatorHash}

// Petition may change the required lovelace on the utxo
pub type Petition {
  lovelace: Int,
}

pub type ByteArrayDataPair {
  key: ByteArray,
  value: Data,
}

pub type ByteArrayIntegerPair {
  key: ByteArray,
  value: Int,
}

pub type ByteArrayValidatorHashPair {
  key: ByteArray,
  value: ValidatorHash,
}

pub type ByteArrayPublicKeyHashPair {
  key: ByteArray,
  value: PublicKeyHash,
}

// general dict data type for the data requried for aipoph
pub type DAODatum {
  data: List<ByteArrayDataPair>,
  version: Int,
}

// find a data structure by a title inside the DAODatum data dictionary.
pub fn find_data(data: DAODatum, key: ByteArray) -> Data {
  do_find_data(data.data, key)
}

fn do_find_data(datas: List<ByteArrayDataPair>, key: ByteArray) -> Data {
  when datas is {
    [] -> fail @"Data Structure Not Found"
    [d, ..ds] ->
      if d.key == key {
        d.value
      } else {
        do_find_data(ds, key)
      }
  }
}

// The threshold structure is a data structure in DAOData
pub type Thresholds =
  List<ByteArrayIntegerPair>

// find a threshold by some key inside the thresholds dictionary.
pub fn find_threshold(thresholds: Thresholds, key: ByteArray) -> Int {
  when thresholds is {
    [] -> fail @"Threshold Not Found"
    [d, ..ds] ->
      if d.key == key {
        d.value
      } else {
        find_threshold(ds, key)
      }
  }
}

// The contract structure is a data structure in DAOData
pub type Contracts =
  List<ByteArrayValidatorHashPair>

// find a contract by title inside the contract dictionary.
pub fn find_contract(contracts: Contracts, key: ByteArray) -> ValidatorHash {
  when contracts is {
    [] -> fail @"Contract Not Found"
    [d, ..ds] ->
      if d.key == key {
        d.value
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
      if x.value == elem {
        delete_contract(xs, elem, holder)
      } else {
        delete_contract(xs, elem, [x.value, ..holder])
      }
  }
}

// The fee structure is a data structure in DAOData
pub type Fees =
  List<ByteArrayIntegerPair>

// find a fee by title inside the fee dictionary.
pub fn find_fee(fees: Fees, key: ByteArray) -> Int {
  when fees is {
    [] -> fail @"Fee Not Found"
    [d, ..ds] ->
      if d.key == key {
        d.value
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
  List<ByteArrayPublicKeyHashPair>

// find a contract by title inside the contract dictionary.
pub fn find_key(keys: Keys, key: ByteArray) -> PublicKeyHash {
  when keys is {
    [] -> fail @"Public Key Hash Not Found"
    [d, ..ds] ->
      if d.key == key {
        d.value
      } else {
        find_key(ds, key)
      }
  }
}
