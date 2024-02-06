//// The DAO data types for `aipoph`
////

use aiken/dict.{Dict}
use aiken/transaction/credential.{PoolId}
use aiken/transaction/value.{Value}
use assist/types/hashes.{ValidatorHash}
use assist/types/wallet.{Wallet}

// Petition may change the required lovelace on the utxo
pub type Petition {
  lovelace: Int,
}

// general dict data type for the data requried for aipoph
pub type DAODatum {
  data: Dict<ByteArray, Data>,
  version: Int,
}

// find a data structure by a title inside the DAODatum data dictionary.
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

// The staking structure is a data structure in DAOData
pub type Staking =
  Dict<ByteArray, StakeData>

// find some stake data by a title inside the staking dictionary.
pub fn find_stake_data(staking: Staking, key: ByteArray) -> StakeData {
  when dict.get(staking, key) is {
    Some(stake) -> stake
    None -> fail @"Stake Data Not Found"
  }
}

pub type StakeData {
  pool_id: PoolId,
  stake_cred: ValidatorHash,
  reward_wallet: Wallet,
}
