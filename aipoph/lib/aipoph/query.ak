use aiken/transaction/credential.{Address}
use aipoph/keys
use aipoph/types/reference.{Contracts, Fees, Keys, ReferenceDatum, Thresholds}
use assist/types/hashes.{PublicKeyHash, ValidatorHash}

/// This is a logical validation to make the genesis contract work. It is an 
/// attempt to solve the genesis problem which is caused by some form of trust
/// being required to send the pointer token with the correct datum to the 
/// correct contract. This works because each update to the reference datum 
/// only checks if the new datum has the initial conditions. The initial 
/// conditions are that the reference contract address inside the datum is teh
/// same as the address being spent from and that the petition threshold is 
/// greater than zero, preventing an instantly bricked reference contract. Both
/// the genesis and the refernce contract run this validation function.
///
/// ```aiken
/// query.does_the_intial_state_exist(this_addr, that_datum)
/// ```
pub fn does_the_intial_state_exist(
  reference_addr: Address,
  reference_datum: ReferenceDatum,
  max_petition_threshold: Int,
) -> Bool {
  // these will fail if the data doesn't exist
  expect contracts: Contracts =
    reference.find_data(reference_datum, keys.contracts)
  let reference_hash: ValidatorHash =
    reference.find_contract(contracts, keys.reference_contract)
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
    (reference_addr == that_reference_addr)?,
    // petition must exist and be positive
    (petition_threshold > 0)?,
    // must and less than or equal to the maximum value
    (petition_threshold <= max_petition_threshold)?,
  }
}

/// Get the petition threshold from the reference datum or fail.
///
/// ```aiken
/// query.get_petition_threshold(ref_datum)
/// ```
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

/// Get the oracle threshold from the reference datum or fail.
///
/// ```aiken
/// query.get_oracle_threshold(ref_datum)
/// ```
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

/// Get the poh test threshold from the reference datum or fail.
///
/// ```aiken
/// query.get_poh_test_threshold(ref_datum)
/// ```
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

/// Get the coh mint threshold from the reference datum or fail.
///
/// ```aiken
/// query.get_coh_mint_threshold(ref_datum)
/// ```
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

/// Get the revoke coh threshold from the reference datum or fail.
///
/// ```aiken
/// query.get_revoke_coh_threshold(ref_datum)
/// ```
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

/// Get the extract vault threshold from the reference datum or fail.
///
/// ```aiken
/// query.get_extract_vault_threshold(ref_datum)
/// ```
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

/// Get the poh lock contract address from the reference datum or fail.
///
/// ```aiken
/// query.get_poh_lock_contract(ref_datum)
/// ```
pub fn get_poh_lock_contract(reference_datum: ReferenceDatum) -> Address {
  expect contract_data: Contracts =
    reference.find_data(reference_datum, keys.contracts)
  let poh_contract_hash: ValidatorHash =
    reference.find_contract(contract_data, keys.poh_lock_contract)
  credential.from_script(poh_contract_hash)
}

/// Get the poh start test maximum fee from the reference datum or fail.
///
/// ```aiken
/// query.get_poh_start_test_fee(ref_datum)
/// ```
pub fn get_poh_start_test_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.poh_start_test)
}

/// Get the poh verified success maximum fee from the reference datum or fail.
///
/// ```aiken
/// query.get_poh_verify_success_fee(ref_datum)
/// ```
pub fn get_poh_verify_success_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.poh_verify_success)
}

/// Get the poh failed test maximum fee from the reference datum or fail.
///
/// ```aiken
/// query.get_poh_verify_fail_fee(ref_datum)
/// ```
pub fn get_poh_verify_fail_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.poh_verify_fail)
}

/// Get the coh revoke maximum fee from the reference datum or fail.
///
/// ```aiken
/// query.get_coh_revoke_fee(ref_datum)
/// ```
pub fn get_coh_revoke_fee(reference_datum: ReferenceDatum) -> Int {
  expect fee_data: Fees = reference.find_data(reference_datum, keys.fees)
  reference.find_fee(fee_data, keys.coh_revoke)
}

/// Get the website public key hash from the reference datum or fail.
///
/// ```aiken
/// query.get_website_hot_key(ref_datum)
/// ```
pub fn get_website_hot_key(reference_datum: ReferenceDatum) -> PublicKeyHash {
  expect keys_data: Keys = reference.find_data(reference_datum, keys.keys)
  reference.find_key(keys_data, keys.website_key)
}
