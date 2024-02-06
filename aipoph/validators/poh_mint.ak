//// this controls the minter for the proof of humanity test. It is used to uniquely
//// identify a specific test.
////

use aiken/transaction.{Input, Mint, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/prove
use aipoph/reference
use aipoph/token_names
use aipoph/types/dao.{Contracts, DAODatum}
use aipoph/types/oracle.{OracleDatum}
use aipoph/types/poh.{
  BurnPoHToken, MintPoHToken, PoHDatum, PoHLockRedeemer, PoHMintRedeemer, Quit,
  StartTest, VerifyTest,
}
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
  // the dao token for voting
  dao_pid: PolicyId,
  dao_tkn: AssetName,
  // the dao contract hash
  dao_hash_data: Data,
) {
  fn params(redeemer: PoHMintRedeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // Mint 1 to 1 tokens
      Mint(own_currency_symbol) -> {
        // this transaction being validated
        let this_tx: Transaction = context.transaction
        // get the dao reference utxo
        let (dao_datum, dao_input): (DAODatum, Input) =
          reference.get_data(this_tx.reference_inputs, dao_hash_data)
        // search the contracts for the poh lock
        expect contract_data: Contracts =
          dao.find_data(dao_datum, keys.contracts)
        // this is the poh lock hash
        let poh_lock_hash: ValidatorHash =
          dao.find_contract(contract_data, keys.poh_lock_contract)
        // build the lock address
        let poh_lock_addr: Address = credential.from_script(poh_lock_hash)
        // find the input being spent from it
        let poh_lock_input: Input =
          find.input_by_addr(this_tx.inputs, poh_lock_addr)
        let this_poh_lock_value: Value = poh_lock_input.output.value
        // get the datum from the lock utxo
        expect poh_lock_datum: PoHDatum = data.input_datum(poh_lock_input)
        // what is being minted or burned in this transaction
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        // this is endpoint specific so check for the correct redeemer
        expect poh_lock_redeemer: PoHLockRedeemer =
          find.redeemer_by_ref(
            this_tx.redeemers,
            poh_lock_input.output_reference,
          )
        // the drep address that can be spent from
        let drep_addr: Address = reference.get_drep_lock_contract(dao_datum)
        when redeemer is {
          // Minting is designed for a threshold actor to come in and prepare a test for the owner.
          // They are paid an incentive and the fee for the tx is already on the utxo. The tx
          // should be designed where the owner just needs to sign a tx without spending anything
          // directly then they choose to start the test when they confirm it.
          MintPoHToken { complexity } ->
            // that redeemer must be the start test redeemer
            when poh_lock_redeemer is {
              // the token can only be minted when the test starts
              StartTest -> {
                // add poh token to the lock value
                // minus the fee and a unit of incentive
                let that_poh_lock_value: Value =
                  value.add(
                    this_poh_lock_value,
                    own_currency_symbol,
                    token_names.poh_token_name,
                    1,
                  )
                    |> value.add(
                         poh_lock_datum.incentive.pid,
                         poh_lock_datum.incentive.tkn,
                         -poh_lock_datum.incentive.amt,
                       )
                    |> value.merge(value.negate(this_tx.fee))
                //
                // the threshold to start the test
                let start_poh_test_threshold: Int =
                  reference.get_poh_test_threshold(dao_datum)
                // maximum fee allowed in this tx
                let max_start_test_fee: Int =
                  reference.get_poh_start_test_fee(dao_datum)
                // this is the oracle hash
                let oracle_hash: ValidatorHash =
                  dao.find_contract(contract_data, keys.oracle_contract)
                // build the oracle address
                let oracle_addr: Address = credential.from_script(oracle_hash)
                // find the oracle input being spent
                let oracle_input: Input =
                  find.input_by_addr(this_tx.inputs, oracle_addr)
                // find the oracle datum, we need the random data
                expect oracle_datum: OracleDatum =
                  data.input_datum(oracle_input)
                // the outbound lock datum
                expect that_poh_lock_datum: PoHDatum =
                  find.output_datum_by_addr(this_tx.outputs, poh_lock_addr)
                //
                // do something with the oracle data here that generates the question?
                // maybe a redeemer exists that combines with this oracle data, this would be the 
                // place to do it.
                //
                // let question_data: Question = question.generate(oracle_datum, complexity)
                //
                // 
                // Mint a poh token to a UTxO if the threshold is met inside the
                // transaction. Only the lock contract and dreps can be spent along
                // this mint action.
                //
                and {
                  // some positive complexity factor
                  complexity > 0,
                  // the oracle data gets assigned to the test data as the rng
                  (that_poh_lock_datum.test_data.random.number == oracle_datum.number)?,
                  (that_poh_lock_datum.test_data.random.string == oracle_datum.string)?,
                  // fee must be less then max fee for starting the test
                  dao.is_valid_fee(this_tx.fee, max_start_test_fee)?,
                  // single script input + many dreps + oracle
                  count.single_input_with_bypass(
                    this_tx.inputs,
                    poh_lock_addr,
                    [drep_addr, oracle_addr],
                  )?,
                  // the continuing value must be sent to the lock address
                  payout.exact(
                    poh_lock_addr,
                    that_poh_lock_value,
                    this_tx.outputs,
                  )?,
                  // must mint 1 poh token
                  minting.exact(
                    mint,
                    own_currency_symbol,
                    token_names.poh_token_name,
                    1,
                  )?,
                  // data reference must be holding correct pointer token
                  values.prove_exact_nft(
                    pointer_pid,
                    pointer_tkn,
                    dao_input.output.value,
                  )?,
                  // do the this_tx meet the threshold
                  tx.total_token_amount(
                    this_tx.inputs,
                    dao_pid,
                    dao_tkn,
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
                    own_currency_symbol,
                    token_names.poh_token_name,
                    this_poh_lock_value,
                  ),
                  // prove you are a human
                  prove.you_are_a_human(
                    poh_lock_datum.test_data.question,
                    poh_lock_datum.test_data.answer,
                  ),
                  // test must have ended
                  poh_lock_datum.test_data.cur_stage == 1,
                } {
                  let max_success_fee: Int =
                    reference.get_poh_verify_success_fee(dao_datum)
                  //
                  // they passed as a human and finished the test
                  // so burn the poh token
                  //
                  and {
                    // fee must be less then max fee
                    dao.is_valid_fee(this_tx.fee, max_success_fee),
                    // must mint 1 reference token,
                    minting.exact(
                      mint,
                      own_currency_symbol,
                      token_names.poh_token_name,
                      -1,
                    ),
                    // data reference must be holding correct token
                    values.prove_exact_nft(
                      pointer_pid,
                      pointer_tkn,
                      dao_input.output.value,
                    ),
                  }
                } else {
                  // they failed the test or didnt finish the test
                  // the user will lose the deposit
                  let vault_hash: ValidatorHash =
                    dao.find_contract(contract_data, keys.vault_contract)
                  // build the vault address
                  let vault_addr: Address = credential.from_script(vault_hash)
                  // find the input being spent from it
                  let vault_input: Input =
                    find.input_by_addr(this_tx.inputs, vault_addr)
                  // this is endpoint specific so check for the correct redeemer
                  expect vault_redeemer: VaultRedeemer =
                    find.redeemer_by_ref(
                      this_tx.redeemers,
                      vault_input.output_reference,
                    )
                  let is_vault_being_spent: Bool =
                    when vault_redeemer is {
                      AddToVault { incoming } -> incoming == incoming
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
                    reference.get_poh_verify_fail_fee(dao_datum)
                  // the drep address that can be spent from
                  let drep_addr: Address =
                    reference.get_drep_lock_contract(dao_datum)
                  //
                  // the user will lose the deposit to the vault while
                  // burning the poh token.
                  //
                  and {
                    // single script input + many dreps + vault
                    count.single_input_with_bypass(
                      this_tx.inputs,
                      poh_lock_addr,
                      [drep_addr, vault_addr],
                    ),
                    // fee must be less then max fee
                    dao.is_valid_fee(this_tx.fee, max_fail_fee),
                    // a vault needs to be spent
                    is_vault_being_spent,
                    // the deposit is sent to the vault
                    payout.at_least(
                      vault_addr,
                      that_vault_value,
                      this_tx.outputs,
                    ),
                    // must mint 1 reference token
                    minting.exact(
                      mint,
                      own_currency_symbol,
                      token_names.poh_token_name,
                      -1,
                    ),
                    // data reference must be holding correct token
                    values.prove_exact_nft(
                      pointer_pid,
                      pointer_tkn,
                      dao_input.output.value,
                    ),
                  }
                }
              // The user is quitting the test and forfetting their deposit to 
              // the vault.
              Quit -> {
                // get the datum from the lock utxo
                expect datum: PoHDatum = data.input_datum(poh_lock_input)
                if datum.test_data.cur_stage == 1 {
                  // The user must wait for their test to be verified
                  fail @"No Leaving During Verification"
                } else {
                  // the user failed the test and lost the deposit
                  let vault_hash: ValidatorHash =
                    dao.find_contract(contract_data, keys.vault_contract)
                  // build the vault address
                  let vault_addr: Address = credential.from_script(vault_hash)
                  // find the input being spent from it
                  let vault_input: Input =
                    find.input_by_addr(this_tx.inputs, vault_addr)
                  let vault_value: Value = vault_input.output.value
                  let that_vault_value: Value =
                    value.add(
                      vault_value,
                      datum.deposit.pid,
                      datum.deposit.tkn,
                      datum.deposit.amt,
                    )
                  and {
                    // single script input + many dreps + vault
                    count.single_input_with_bypass(
                      this_tx.inputs,
                      poh_lock_addr,
                      [drep_addr, vault_addr],
                    )?,
                    // must mint 1 reference token
                    minting.exact(
                      mint,
                      own_currency_symbol,
                      token_names.poh_token_name,
                      -1,
                    )?,
                    // data reference must be holding correct token
                    values.prove_exact_nft(
                      pointer_pid,
                      pointer_tkn,
                      dao_input.output.value,
                    )?,
                    // the deposit is sent to the vault
                    payout.at_least(
                      vault_addr,
                      that_vault_value,
                      this_tx.outputs,
                    )?,
                  }
                }
              }
              // anything else fail
              _ -> fail @"Incorrect PoH Redeemer"
            }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
