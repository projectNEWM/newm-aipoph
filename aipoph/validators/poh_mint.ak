//// This controls the minter for the proof of humanity pointer token. The 
//// token is used to uniquely identify a specific test and indicates that a 
//// test is currently live and active. The minting of the token can only 
//// occur during the StartTest endpoint. The burning of the token can occur
//// during the VerifyTest or the Quit endpoint. If a user burns the token 
//// during the Quit endpoint then the deposit is sent to the vault as the user
//// is prematurely leaving a live test. If a user fails the test then the 
//// token is burned and the deposit goes to the vault.
////

use aiken/transaction.{Input, Mint, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/query
use aipoph/token_names
use aipoph/types/oracle.{OracleDatum}
use aipoph/types/poh.{
  BurnPoHToken, MintPoHToken, PoHDatum, PoHLockRedeemer, PoHMintRedeemer, Quit,
  StartTest, VerifyTest,
}
use aipoph/types/prove
use aipoph/types/reference.{Contracts, ReferenceDatum}
use aipoph/types/vault.{AddToVault, VaultRedeemer}
use assist/count
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/tx
use assist/types/hashes.{ValidatorHash}
use assist/values

validator(
  // the pointer token for pointing at
  pointer_pid: PolicyId,
  pointer_tkn: AssetName,
  // the action token for voting
  action_pid: PolicyId,
  action_tkn: AssetName,
  // the reference contract hash
  ref_data_hash: ValidatorHash,
) {
  fn params(redeemer: PoHMintRedeemer, context: ScriptContext) -> Bool {
    // must be minting
    expect Mint(currency_symbol) = context.purpose
    // destruct the tx with required fields
    let Transaction {
      inputs,
      outputs,
      reference_inputs,
      mint,
      fee,
      redeemers,
      ..
    } = context.transaction
    // get the reference utxo and datum
    let ref_data_addr: Address = credential.from_script(ref_data_hash)
    let ref_data_input: Input =
      find.input_by_addr(reference_inputs, ref_data_addr)
    expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
    // search the contracts for the poh lock
    expect contract_data: Contracts =
      reference.find_data(ref_data_datum, keys.contracts)
    // this is the poh lock hash
    let poh_lock_hash: ValidatorHash =
      reference.find_contract(contract_data, keys.poh_lock_contract)
    // build the lock address
    let poh_lock_addr: Address = credential.from_script(poh_lock_hash)
    // find the input being spent from it
    let poh_lock_input: Input = find.input_by_addr(inputs, poh_lock_addr)
    let this_poh_lock_value: Value = poh_lock_input.output.value
    // get the datum from the lock utxo
    expect poh_lock_datum: PoHDatum = data.input_datum(poh_lock_input)
    // what is being minted or burned in this transaction
    let mint_list: List<(PolicyId, AssetName, Int)> =
      mint
        |> value.from_minted_value()
        |> value.flatten()
    // this is endpoint specific so check for the correct redeemer
    expect poh_lock_redeemer: PoHLockRedeemer =
      find.redeemer_by_ref(redeemers, poh_lock_input.output_reference)
    when redeemer is {
      // Minting is designed for a threshold actor to come in and prepare a test for the owner.
      // They are paid an incentive and the fee for the tx is already on the utxo. The tx
      // should be designed where the owner just needs to sign a tx without spending anything
      // directly then they choose to start the test when they confirm it.
      MintPoHToken ->
        // that redeemer must be the start test redeemer
        when poh_lock_redeemer is {
          // the token can only be minted when the test starts
          StartTest -> {
            // add poh token to the lock value
            // minus the fee and a unit of incentive
            let that_poh_lock_value: Value =
              value.add(
                this_poh_lock_value,
                currency_symbol,
                token_names.poh_token_name,
                1,
              )
                |> value.add(
                    poh_lock_datum.incentive.pid,
                    poh_lock_datum.incentive.tkn,
                    -poh_lock_datum.incentive.amt,
                  )
                |> value.merge(value.negate(fee))
            //
            // the threshold to start the test
            let start_poh_test_threshold: Int =
              query.get_poh_test_threshold(ref_data_datum)
            // maximum fee allowed in this tx
            let max_start_test_fee: Int =
              query.get_poh_start_test_fee(ref_data_datum)
            // this is the oracle hash
            let oracle_hash: ValidatorHash =
              reference.find_contract(contract_data, keys.oracle_contract)
            // build the oracle address
            let oracle_addr: Address = credential.from_script(oracle_hash)
            // find the oracle input being spent
            let oracle_input: Input = find.input_by_addr(inputs, oracle_addr)
            // find the oracle datum, we need the random data
            expect oracle_datum: OracleDatum = data.input_datum(oracle_input)
            // the outbound lock datum
            expect that_poh_lock_datum: PoHDatum =
              find.output_datum_by_addr(outputs, poh_lock_addr)
            //
            // The question is generated off-chain to minimize cost and increase security.
            // 
            // Mint a poh token to a UTxO if the threshold is met inside the
            // transaction. Only the lock contract can be spent along
            // this mint action.
            //
            and {
              // the oracle data gets assigned to the test data as the rng
              (that_poh_lock_datum.test_data.random.number == oracle_datum.number)?,
              (that_poh_lock_datum.test_data.random.string == oracle_datum.string)?,
              // fee must be less then max fee for starting the test
              reference.is_valid_fee(fee, max_start_test_fee)?,
              // single script input + oracle
              count.single_input_with_bypass(
                inputs,
                poh_lock_addr,
                [oracle_addr],
              )?,
              // the continuing value must be sent to the lock address
              payout.exact(poh_lock_addr, that_poh_lock_value, outputs)?,
              // must mint 1 poh token
              minting.exact(
                mint_list,
                currency_symbol,
                token_names.poh_token_name,
                1,
              )?,
              // data reference must be holding correct pointer token
              values.prove_exact_nft(
                ref_data_input.output.value,
                pointer_pid,
                pointer_tkn,
              )?,
              // do the this_tx meet the threshold
              tx.total_token_amount(
                inputs,
                action_pid,
                action_tkn,
                start_poh_test_threshold,
              )?,
            }
          }
          // anything else fail
          _ -> fail @"Not Starting Test"
        }
      // Burning is designed to only happen during a verification and when a user is quitting.
      // In all the cases a token will be burned but the deposit may or may not be lost
      // to the vault.
      BurnPoHToken ->
        when poh_lock_redeemer is {
          // A threshold actor is verifying the test.
          VerifyTest ->
            if and {
              // this checks if the test started
              values.prove_exact_nft(
                this_poh_lock_value,
                currency_symbol,
                token_names.poh_token_name,
              ),
              // prove you are a human
              prove.you_are_a_human(
                poh_lock_datum.test_data.question,
                poh_lock_datum.test_data.answer,
              ),
              // prove that the answer is signed correctly
              prove.correct_signers(
                poh_lock_datum.test_data.answer,
                poh_lock_datum.owner.pkh,
                query.get_website_hot_key(ref_data_datum),
              ),
              // test must have ended
              poh_lock_datum.test_data.cur_stage == 1,
            } {
              let max_success_fee: Int =
                query.get_poh_verify_success_fee(ref_data_datum)
              //
              // They passed as a human and finished the test
              // so burn the poh token.
              //
              and {
                // fee must be less then max fee
                reference.is_valid_fee(fee, max_success_fee)?,
                // must mint 1 reference token,
                minting.exact(
                  mint_list,
                  currency_symbol,
                  token_names.poh_token_name,
                  -1,
                )?,
                // data reference must be holding correct token
                values.prove_exact_nft(
                  ref_data_input.output.value,
                  pointer_pid,
                  pointer_tkn,
                )?,
              }
            } else {
              // they failed the test or didnt finish the test
              // the user will lose the deposit
              let vault_hash: ValidatorHash =
                reference.find_contract(contract_data, keys.vault_contract)
              // build the vault address
              let vault_addr: Address = credential.from_script(vault_hash)
              // find the input being spent from it
              let vault_input: Input = find.input_by_addr(inputs, vault_addr)
              // this is endpoint specific so check for the correct redeemer
              expect vault_redeemer: VaultRedeemer =
                find.redeemer_by_ref(redeemers, vault_input.output_reference)
              let is_vault_being_spent: Bool =
                when vault_redeemer is {
                  AddToVault(_) -> True
                  _ -> False
                }
              let vault_value: Value = vault_input.output.value
              let that_vault_value: Value =
                value.add(
                  vault_value,
                  poh_lock_datum.deposit.pid,
                  poh_lock_datum.deposit.tkn,
                  poh_lock_datum.deposit.amt,
                )
              let max_fail_fee: Int =
                query.get_poh_verify_fail_fee(ref_data_datum)
              //
              // The user did not pass the test and will lose the deposit to 
              // the vault while burning the poh token.
              //
              and {
                // single script input + vault
                count.single_input_with_bypass(
                  inputs,
                  poh_lock_addr,
                  [vault_addr],
                )?,
                // fee must be less then max fee
                reference.is_valid_fee(fee, max_fail_fee)?,
                // a vault needs to be spent
                is_vault_being_spent?,
                // the deposit is sent to the vault
                payout.at_least(vault_addr, that_vault_value, outputs)?,
                // must mint 1 reference token
                minting.exact(
                  mint_list,
                  currency_symbol,
                  token_names.poh_token_name,
                  -1,
                )?,
                // data reference must be holding correct token
                values.prove_exact_nft(
                  ref_data_input.output.value,
                  pointer_pid,
                  pointer_tkn,
                )?,
              }
            }
          // The user is quitting the test and forfetting their deposit to 
          // the vault.
          Quit -> {
            // get the datum from the lock utxo
            expect datum: PoHDatum = data.input_datum(poh_lock_input)
            // the user failed the test and lost the deposit
            let vault_hash: ValidatorHash =
              reference.find_contract(contract_data, keys.vault_contract)
            // build the vault address
            let vault_addr: Address = credential.from_script(vault_hash)
            // find the input being spent from it
            let vault_input: Input = find.input_by_addr(inputs, vault_addr)
            let vault_value: Value = vault_input.output.value
            let that_vault_value: Value =
              value.add(
                vault_value,
                datum.deposit.pid,
                datum.deposit.tkn,
                datum.deposit.amt,
              )
            //
            // Quiting and burning means the test was live and the user left
            // prematurely. Quitting while the test is live is an automatic
            // lost of deposit. The deposit is sent to the vault.
            //
            and {
              // single script input + vault
              count.single_input_with_bypass(
                inputs,
                poh_lock_addr,
                [vault_addr],
              )?,
              // must mint 1 reference token
              minting.exact(
                mint_list,
                currency_symbol,
                token_names.poh_token_name,
                -1,
              )?,
              // data reference must be holding correct token
              values.prove_exact_nft(
                ref_data_input.output.value,
                pointer_pid,
                pointer_tkn,
              )?,
              // the deposit is sent to the vault
              payout.at_least(vault_addr, that_vault_value, outputs)?,
            }
          }
          // anything else fail
          _ -> fail @"Incorrect PoH Redeemer"
        }
    }
  }
}
