use aiken/transaction.{Input}
use aiken/transaction/credential.{Address}
use aipoph/keys
use aipoph/types.{ValidatorHash}
use aipoph/types/dao.{DAODatum, Thresholds}
use assist/data
use assist/find

/// Get the dao data from the reference inputs
pub fn get_data(
  reference_inputs: List<Input>,
  dao_hash_data: Data,
) -> (DAODatum, Input) {
  expect dao_hash: ValidatorHash = dao_hash_data
  let dao_addr: Address = credential.from_script(dao_hash)
  let dao_input: Input = find.input_by_addr(reference_inputs, dao_addr)
  expect dao_datum: DAODatum = data.input_datum(dao_input)
  (dao_datum, dao_input)
}

pub fn get_petition_threshold(dao_datum: DAODatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let petition_threshold: Int =
    dao.find_threshold(threshold_data, keys.petition_threshold)
  petition_threshold
}

/// get the oracle threshold or fail
pub fn get_oracle_threshold(dao_datum: DAODatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let oracle_threshold: Int =
    dao.find_threshold(threshold_data, keys.oracle_threshold)
  oracle_threshold
}

/// get the start poh test threshold or fail
pub fn get_poh_test_threshold(dao_datum: DAODatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let start_poh_test_threshold: Int =
    dao.find_threshold(threshold_data, keys.start_poh_test_threshold)
  start_poh_test_threshold
}

/// get the extract_vault threshold or fail
pub fn get_extract_vault_threshold(dao_datum: DAODatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let extract_vault_threshold: Int =
    dao.find_threshold(threshold_data, keys.extract_vault_threshold)
  extract_vault_threshold
}
