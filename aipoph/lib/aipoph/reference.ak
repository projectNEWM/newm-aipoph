use aiken/transaction.{Input}
use aiken/transaction/credential.{Address}
use aipoph/keys
use aipoph/types/dao.{Contracts, DAODatum, Fees, Thresholds}
use assist/data
use assist/find
use assist/types/hashes.{ValidatorHash}

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

pub fn does_the_intial_state_exist(
  dao_addr: Address,
  dao_datum: DAODatum,
) -> Bool {
  // these will fail if the data doesn't exist
  expect contracts: Contracts = dao.find_data(dao_datum, keys.contracts)
  let dao_hash: ValidatorHash = dao.find_contract(contracts, keys.dao_contract)
  let drep_hash: ValidatorHash =
    dao.find_contract(contracts, keys.drep_lock_contract)
  // no stake
  let that_dao_addr: Address = credential.from_script(dao_hash)
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  let petition_threshold: Int =
    dao.find_threshold(threshold_data, keys.petition_threshold)
  //
  // check that the address exists in the data, the data must have a petition
  // threshold, and the threshold is positive.
  //
  and {
    // addresses has to exist
    dao_addr == that_dao_addr,
    // petition must exist and be positive
    petition_threshold > 0,
    // drep hash has to exist
    drep_hash == drep_hash,
  }
}

pub fn does_petition_threshold_exist(dao_datum: DAODatum) -> Bool {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let petition_threshold: Int =
    dao.find_threshold(threshold_data, keys.petition_threshold)
  petition_threshold > 0
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

/// get the start poh test threshold or fail
pub fn get_coh_mint_threshold(dao_datum: DAODatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let mint_coh_threshold: Int =
    dao.find_threshold(threshold_data, keys.mint_coh_threshold)
  mint_coh_threshold
}

/// get the start poh test threshold or fail
pub fn get_revoke_coh_threshold(dao_datum: DAODatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds = dao.find_data(dao_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let revoke_coh_threshold: Int =
    dao.find_threshold(threshold_data, keys.revoke_coh_threshold)
  revoke_coh_threshold
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

pub fn get_drep_lock_contract(dao_datum: DAODatum) -> Address {
  expect contract_data: Contracts = dao.find_data(dao_datum, keys.contracts)
  let drep_contract_hash: ValidatorHash =
    dao.find_contract(contract_data, keys.drep_lock_contract)
  credential.from_script(drep_contract_hash)
}

pub fn get_poh_lock_contract(dao_datum: DAODatum) -> Address {
  expect contract_data: Contracts = dao.find_data(dao_datum, keys.contracts)
  let poh_contract_hash: ValidatorHash =
    dao.find_contract(contract_data, keys.poh_lock_contract)
  credential.from_script(poh_contract_hash)
}

pub fn get_coh_lock_contract(dao_datum: DAODatum) -> Address {
  expect contract_data: Contracts = dao.find_data(dao_datum, keys.contracts)
  let coh_contract_hash: ValidatorHash =
    dao.find_contract(contract_data, keys.coh_lock_contract)
  credential.from_script(coh_contract_hash)
}

pub fn get_oracle_contract(dao_datum: DAODatum) -> Address {
  expect contract_data: Contracts = dao.find_data(dao_datum, keys.contracts)
  let oracle_contract_hash: ValidatorHash =
    dao.find_contract(contract_data, keys.oracle_contract)
  credential.from_script(oracle_contract_hash)
}

pub fn get_poh_start_test_fee(dao_datum: DAODatum) -> Int {
  expect fee_data: Fees = dao.find_data(dao_datum, keys.fees)
  dao.find_fee(fee_data, keys.poh_start_test)
}

pub fn get_poh_verify_success_fee(dao_datum: DAODatum) -> Int {
  expect fee_data: Fees = dao.find_data(dao_datum, keys.fees)
  dao.find_fee(fee_data, keys.poh_verify_success)
}

pub fn get_poh_verify_fail_fee(dao_datum: DAODatum) -> Int {
  expect fee_data: Fees = dao.find_data(dao_datum, keys.fees)
  dao.find_fee(fee_data, keys.poh_verify_fail)
}

pub fn get_coh_revoke_fee(dao_datum: DAODatum) -> Int {
  expect fee_data: Fees = dao.find_data(dao_datum, keys.fees)
  dao.find_fee(fee_data, keys.coh_revoke)
}
