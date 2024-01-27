//// The DAO data types for `aipoph`
////

use aiken/dict.{Dict}
use aiken/transaction/value.{Value}
use assist/types/hashes.{ValidatorHash}

// Petition may change the required lovelace on the utxo
pub type Petition {
  lovelace: Int,
}

// general dict data type for the DAO
pub type DAODatum {
  data: Dict<ByteArray, Data>,
  version: Int,
}

// find a data structure by a title inside the DAOData dictionary.
pub fn find_data(data: DAODatum, key: ByteArray) -> Data {
  when dict.get(data.data, key) is {
    Some(thing) -> thing
    None -> fail @"Data Structure Not Found"
  }
}

// The threshold structure is a data structure in DAOData
pub type Thresholds =
  Dict<ByteArray, Int>

// find a threshold by some key inside the thresholds dictionary.
pub fn find_threshold(thresholds: Thresholds, key: ByteArray) -> Int {
  when dict.get(thresholds, key) is {
    Some(threshold) -> threshold
    None -> fail @"Threshold Not Found"
  }
}

// The contract structure is a data structure in DAOData
pub type Contracts =
  Dict<ByteArray, ValidatorHash>

// find a contract by title inside the contract dictionary.
pub fn find_contract(contracts: Contracts, key: ByteArray) -> ValidatorHash {
  when dict.get(contracts, key) is {
    Some(contract) -> contract
    None -> fail @"Contract Not Found"
  }
}

// The fee structure is a data structure in DAOData
pub type Fees =
  Dict<ByteArray, Int>

// find a fee by title inside the fee dictionary.
pub fn find_fee(fees: Fees, key: ByteArray) -> Int {
  when dict.get(fees, key) is {
    Some(fee) -> fee
    None -> fail @"Fee Not Found"
  }
}

pub fn is_valid_fee(this_fee: Value, fee: Int) -> Bool {
  let lovelace: Int =
    value.quantity_of(this_fee, value.ada_policy_id, value.ada_asset_name)
  fee > lovelace
}
