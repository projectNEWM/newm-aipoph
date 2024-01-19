//// this controls the minting of the certificate of humanity.
//// this controls the minter for the proof of humanity test. It is used to uniquely
//// identify a specific test.

use aiken/transaction.{Input, Mint, Output, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/catch
use aipoph/keys
use aipoph/reference
use aipoph/token_names
use aipoph/types/coh.{
  BurnCoHToken, CoHDatum, CoHLockRedeemer, CoHMintRedeemer, MintCoHToken, Revoke,
}
use aipoph/types/dao.{Contracts, DAODatum}
use aipoph/types/poh.{PoHDatum, PoHLockRedeemer, VerifyTest}
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/prefixes
use assist/tx
use assist/types.{Token, ValidatorHash}
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
  fn params(redeemer: CoHMintRedeemer, context: ScriptContext) -> Bool {
    when context.purpose is {
      // Mint 1 to 1 tokens
      Mint(own_currency_symbol) -> {
        // this transaction being validated
        let this_tx: Transaction = context.transaction
        // get the dao reference utxo
        let (dao_datum, dao_input): (DAODatum, Input) =
          reference.get_data(this_tx.reference_inputs, dao_hash_data)
        // search the contracts for the coh lock
        expect contract_data: Contracts =
          dao.find_data(dao_datum, keys.contracts)
        // this is the coh lock hash
        let coh_lock_hash: ValidatorHash =
          dao.find_contract(contract_data, keys.coh_lock_contract)
        // build the lock address
        let coh_lock_addr: Address = credential.from_script(coh_lock_hash)
        // find the output being sent to the coh lock address
        let coh_lock_output: Output =
          find.output_by_addr(this_tx.outputs, coh_lock_addr)
        // the coh datum on the output
        expect coh_lock_datum: CoHDatum = data.output_datum(coh_lock_output)
        let coh_lock_value: Value = coh_lock_output.value
        // what is being minted or burned in this transaction
        let mint: List<(PolicyId, AssetName, Int)> =
          this_tx.mint
            |> value.from_minted_value()
            |> value.flatten()
        // the drep address that can be spent from
        let drep_addr: Address = reference.get_drep_lock_contract(dao_datum)
        when redeemer is {
          // mint the poh token
          MintCoHToken -> {
            // this is the poh lock hash
            let poh_lock_hash: ValidatorHash =
              dao.find_contract(contract_data, keys.poh_lock_contract)
            // build the lock address
            let poh_lock_addr: Address = credential.from_script(poh_lock_hash)
            // find the input being spent from it
            let poh_lock_input: Input =
              find.input_by_addr(this_tx.inputs, poh_lock_addr)
            // get the datum from the lock utxo
            expect poh_lock_datum: PoHDatum = data.input_datum(poh_lock_input)
            // this is endpoint specific so check for the correct redeemer
            expect poh_lock_redeemer: PoHLockRedeemer =
              find.redeemer_by_ref(
                this_tx.redeemers,
                poh_lock_input.output_reference,
              )
            // that redeemer must be the start test redeemer
            when poh_lock_redeemer is {
              // the token can only be minted when the test starts
              VerifyTest -> {
                // the threshold to start the test
                let coh_mint_threshold: Int =
                  reference.get_coh_mint_threshold(dao_datum)
                // this is a unique pointer inside the utxo
                let coh_pointer_token_name: AssetName =
                  values.unique_token_name(
                    poh_lock_input.output_reference.transaction_id.hash,
                    poh_lock_input.output_reference.output_index,
                    prefixes.prefix_callable,
                  )
                let coh_pointer_token: Token =
                  Token {
                    pid: own_currency_symbol,
                    tkn: coh_pointer_token_name,
                    amt: 1,
                  }
                //
                // Mint a poh token to a UTxO if the threshold is met inside the
                // transaction. Only the lock contract and dreps can be spent along
                // this mint action.
                //
                and {
                  // Need to make sure the coh datum is set up correctly
                  coh.poh_into_coh(
                    poh_lock_datum,
                    coh_lock_datum,
                    coh_pointer_token,
                    this_tx.validity_range,
                  ),
                  // single script input + many dreps
                  catch.specific_inputs_only(
                    this_tx.inputs,
                    poh_lock_addr,
                    [drep_addr],
                  ),
                  // must mint 1 coh token
                  minting.exact(
                    mint,
                    own_currency_symbol,
                    token_names.coh_token_name,
                    1,
                  ),
                  // the coh lock value must be holding the coh token
                  values.prove_exact_nft(
                    own_currency_symbol,
                    token_names.coh_token_name,
                    coh_lock_value,
                  ),
                  // must mint 1 coh pointer token
                  minting.exact(
                    mint,
                    own_currency_symbol,
                    coh_pointer_token_name,
                    1,
                  ),
                  // the coh lock value must be holding the coh pointer token
                  values.prove_exact_nft(
                    own_currency_symbol,
                    coh_pointer_token_name,
                    coh_lock_value,
                  ),
                  // do the this_tx meet the threshold
                  tx.total_token_amount(
                    this_tx.inputs,
                    dao_pid,
                    dao_tkn,
                    coh_mint_threshold,
                  ),
                }
              }
              // anything else fail
              _ -> fail @"Not Verifying Test"
            }
          }
          // burn the poh token
          BurnCoHToken -> {
            // the input being spent
            let coh_lock_input: Input =
              find.input_by_addr(this_tx.inputs, coh_lock_addr)
            // this value being spent minus the fee
            let coh_lock_value: Value =
              coh_lock_input.output.value
                |> value.merge(value.negate(this_tx.fee))
            // get the datum from the lock utxo
            expect coh_lock_datum: CoHDatum = data.input_datum(coh_lock_input)
            // // this is endpoint specific so check for the correct redeemer
            expect coh_lock_redeemer: CoHLockRedeemer =
              find.redeemer_by_ref(
                this_tx.redeemers,
                coh_lock_input.output_reference,
              )
            // the user will lose the ada to the vault
            let vault_hash: ValidatorHash =
              dao.find_contract(contract_data, keys.vault_contract)
            // build the vault address
            let vault_addr: Address = credential.from_script(vault_hash)
            // find the input being spent from it
            let vault_input: Input =
              find.input_by_addr(this_tx.inputs, vault_addr)
            let vault_value: Value = vault_input.output.value
            // add in the leftover lovelace from this value
            let cont_vault_value: Value =
              value.add(
                vault_value,
                value.ada_policy_id,
                value.ada_asset_name,
                value.lovelace_of(coh_lock_value),
              )
            // the threshold to start the test
            let coh_revoke_threshold: Int =
              reference.get_revoke_coh_threshold(dao_datum)
            let max_revoke_fee: Int = reference.get_coh_revoke_fee(dao_datum)
            when coh_lock_redeemer is {
              // the test is being verified
              Revoke -> and {
                  // single script input + many dreps
                  catch.specific_inputs_only(
                    this_tx.inputs,
                    coh_lock_addr,
                    [drep_addr, vault_addr],
                  ),
                  // fee must be less then max fee
                  dao.is_valid_fee(this_tx.fee, max_revoke_fee),
                  // the ada is sent to the vault
                  payout.at_least(vault_addr, cont_vault_value, this_tx.outputs),
                  // must mint 1 coh pointer token
                  minting.exact(
                    mint,
                    own_currency_symbol,
                    coh_lock_datum.verification.pointer.tkn,
                    -1,
                  ),
                  // must mint 1 coh token
                  minting.exact(
                    mint,
                    own_currency_symbol,
                    token_names.coh_token_name,
                    -1,
                  ),
                  // do the this_tx meet the threshold
                  tx.total_token_amount(
                    this_tx.inputs,
                    dao_pid,
                    dao_tkn,
                    coh_revoke_threshold,
                  ),
                  // data reference must be holding correct token
                  values.prove_exact_nft(
                    pointer_pid,
                    pointer_tkn,
                    dao_input.output.value,
                  ),
                }
              // anything else fail
              _ -> fail @"Incorrect CoH Redeemer"
            }
          }
        }
      }
      // anything else fails
      _ -> False
    }
  }
}
