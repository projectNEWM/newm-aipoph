use aiken/transaction.{Input}
use aiken/transaction/credential.{Address}
use aipoph/keys
use aipoph/types/reference.{Contracts, Fees, ReferenceDatum, Thresholds}
use assist/data
use assist/find
use assist/types/hashes.{ValidatorHash}

/// Get the reference data from the reference inputs
pub fn get_data(
  reference_inputs: List<Input>,
  reference_hash_data: Data,
) -> (ReferenceDatum, Input) {
  expect reference_hash: ValidatorHash = reference_hash_data
  let reference_addr: Address = credential.from_script(reference_hash)
  let reference_input: Input =
    find.input_by_addr(reference_inputs, reference_addr)
  expect reference_datum: ReferenceDatum = data.input_datum(reference_input)
  (reference_datum, reference_input)
}

pub fn does_the_intial_state_exist(
  reference_addr: Address,
  reference_datum: ReferenceDatum,
) -> Bool {
  // these will fail if the data doesn't exist
  expect contracts: Contracts =
    reference.find_data(reference_datum, keys.contracts)
  let reference_hash: ValidatorHash =
    reference.find_contract(contracts, keys.reference_contract)
  let drep_hash: ValidatorHash =
    reference.find_contract(contracts, keys.drep_lock_contract)
  // no stake
  let that_reference_addr: Address = credential.from_script(reference_hash)
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  let petition_threshold: Int =
    reference.find_threshold(threshold_data, keys.petition_threshold)
  //
  // check that the address exists in the data, the data must have a petition
  // threshold, and the threshold is positive.
  //
  and {
    // addresses has to exist
    reference_addr == that_reference_addr,
    // petition must exist and be positive
    petition_threshold > 0,
    // drep hash has to exist
    drep_hash == drep_hash,
  }
}

pub fn get_petition_threshold(reference_datum: ReferenceDatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let petition_threshold: Int =
    reference.find_threshold(threshold_data, keys.petition_threshold)
  petition_threshold
}

/// get the oracle threshold or fail
pub fn get_oracle_threshold(reference_datum: ReferenceDatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let oracle_threshold: Int =
    reference.find_threshold(threshold_data, keys.oracle_threshold)
  oracle_threshold
}

/// get the start poh test threshold or fail
pub fn get_poh_test_threshold(reference_datum: ReferenceDatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let start_poh_test_threshold: Int =
    reference.find_threshold(threshold_data, keys.start_poh_test_threshold)
  start_poh_test_threshold
}

/// get the start poh test threshold or fail
pub fn get_coh_mint_threshold(reference_datum: ReferenceDatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let mint_coh_threshold: Int =
    reference.find_threshold(threshold_data, keys.mint_coh_threshold)
  mint_coh_threshold
}

/// get the start poh test threshold or fail
pub fn get_revoke_coh_threshold(reference_datum: ReferenceDatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let revoke_coh_threshold: Int =
    reference.find_threshold(threshold_data, keys.revoke_coh_threshold)
  revoke_coh_threshold
}

/// get the extract_vault threshold or fail
pub fn get_extract_vault_threshold(reference_datum: ReferenceDatum) -> Int {
  // this will fail if it doesn't exist
  expect threshold_data: Thresholds =
    reference.find_data(reference_datum, keys.thresholds)
  // the threshold to change data
  // this will fail if it doesn't exist
  let extract_vault_threshold: Int =
    reference.find_threshold(threshold_data, keys.extract_vault_threshold)
  extract_vault_threshold
}

pub fn get_drep_lock_contract(reference_datum: ReferenceDatum) -> Address {
  expect contract_data: Contracts =
    reference.find_data(reference_datum, keys.contracts)
  let drep_contract_hash: ValidatorHash =
    reference.find_contract(contract_data, keys.drep_lock_contract)
  credential.from_script(drep_contract_hash)
}

pub fn get_poh_lock_contract(reference_datum: ReferenceDatum) -> Address {
  expect contract_data: Contracts =
    reference.find_data(reference_datum, keys.contracts)
  let poh_contract_hash: ValidatorHash =
    reference.find_contract(contract_data, keys.poh_lock_contract)
  credential.from_script(poh_contract_hash)
}

pub fn get_poh_start_test_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.poh_start_test)
}

pub fn get_poh_verify_success_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.poh_verify_success)
}

pub fn get_poh_verify_fail_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.poh_verify_fail)
}

pub fn get_coh_revoke_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.coh_revoke)
}
