//// All the data types for `aipoph`.
////

use aiken/dict.{Dict}
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

// find a worker by job title inside the worker hot key dictionary.
pub fn find_contract(contracts: Contracts, key: ByteArray) -> ValidatorHash {
  when dict.get(contracts, key) is {
    Some(contract) -> contract
    None -> fail @"Contract Not Found"
  }
}
