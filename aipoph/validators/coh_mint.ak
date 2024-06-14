//// This controls the minting of the certificate of humanity. The minting
//// action can only occur during the VerifyTest endpoint. The burning action
//// during the Revoke endpoint. When burning a certificate of humanity the
//// leftover value on the UTxO is sent to the vault.

use aiken/transaction.{Input, Mint, Output, ScriptContext, Transaction}
use aiken/transaction/credential.{Address}
use aiken/transaction/value.{AssetName, PolicyId, Value}
use aipoph/keys
use aipoph/query
use aipoph/token_names
use aipoph/types/coh.{
  BurnCoHToken, CoHDatum, CoHLockRedeemer, CoHMintRedeemer, MintCoHToken, Revoke,
}
use aipoph/types/poh.{PoHDatum, PoHLockRedeemer, VerifyTest}
use aipoph/types/reference.{Contracts, ReferenceDatum}
use aipoph/types/vault.{AddToVault, VaultRedeemer}
use assist/count
use assist/data
use assist/find
use assist/minting
use assist/payout
use assist/prefixes
use assist/tx
use assist/types/hashes.{ValidatorHash}
use assist/types/token.{Token}
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
  fn params(redeemer: CoHMintRedeemer, context: ScriptContext) -> Bool {
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
      validity_range,
      ..
    } = context.transaction
    // get the reference utxo and datum
    let ref_data_addr: Address = credential.from_script(ref_data_hash)
    let ref_data_input: Input =
      find.input_by_addr(reference_inputs, ref_data_addr)
    expect ref_data_datum: ReferenceDatum = data.input_datum(ref_data_input)
    // search the contracts for the coh lock
    expect contract_data: Contracts =
      reference.find_data(ref_data_datum, keys.contracts)
    // this is the coh lock hash
    let coh_lock_hash: ValidatorHash =
      reference.find_contract(contract_data, keys.coh_lock_contract)
    // build the lock address
    let coh_lock_addr: Address = credential.from_script(coh_lock_hash)
    // find the output being sent to the coh lock address
    let coh_lock_output: Output = find.output_by_addr(outputs, coh_lock_addr)
    // the coh datum on the output
    expect coh_lock_datum: CoHDatum = data.output_datum(coh_lock_output)
    let coh_lock_value: Value = coh_lock_output.value
    // what is being minted or burned in this transaction
    let mint_list: List<(PolicyId, AssetName, Int)> =
      mint
        |> value.from_minted_value()
        |> value.flatten()
    when redeemer is {
      // mint the poh token
      MintCoHToken -> {
        // this is the poh lock hash
        let poh_lock_hash: ValidatorHash =
          reference.find_contract(contract_data, keys.poh_lock_contract)
        // build the lock address
        let poh_lock_addr: Address = credential.from_script(poh_lock_hash)
        // find the input being spent from it
        let poh_lock_input: Input = find.input_by_addr(inputs, poh_lock_addr)
        // get the datum from the lock utxo
        expect poh_lock_datum: PoHDatum = data.input_datum(poh_lock_input)
        // this is endpoint specific so check for the correct redeemer
        expect poh_lock_redeemer: PoHLockRedeemer =
          find.redeemer_by_ref(redeemers, poh_lock_input.output_reference)
        // that redeemer must be the start test redeemer
        when poh_lock_redeemer is {
          // the token can only be minted when the test starts
          VerifyTest -> {
            // the threshold to start the test
            let coh_mint_threshold: Int =
              query.get_coh_mint_threshold(ref_data_datum)
            // this is a unique pointer inside the utxo
            let coh_pointer_token_name: AssetName =
              values.unique_token_name(
                poh_lock_input.output_reference.transaction_id.hash,
                poh_lock_input.output_reference.output_index,
                prefixes.callable,
              )
            let coh_pointer_token: Token =
              Token {
                pid: currency_symbol,
                tkn: coh_pointer_token_name,
                amt: 1,
              }
            //
            // Mints a coh token and a pointer token into the coh lock 
            // contract. The poh datum is transferred into the coh datum. The
            // value validation is implicit and only proving exact nft is used.
            //
            and {
              // Need to make sure the coh datum is set up correctly
              // coh datum is from an output
              coh.poh_into_coh(
                poh_lock_datum,
                coh_lock_datum,
                coh_pointer_token,
                validity_range,
              )?,
              // single script input
              count.inputs_by_addr(inputs, poh_lock_addr, 1)?,
              // single script output to coh lock adddress
              count.outputs_by_addr(outputs, coh_lock_addr, 1)?,
              // must mint 1 coh token
              minting.exact(
                mint_list,
                currency_symbol,
                token_names.coh_token_name,
                1,
              )?,
              // the coh lock value must be holding the coh token
              values.prove_exact_nft(
                coh_lock_value,
                currency_symbol,
                token_names.coh_token_name,
              )?,
              // must mint 1 coh pointer token
              minting.exact(
                mint_list,
                currency_symbol,
                coh_pointer_token_name,
                1,
              )?,
              // the coh lock value must be holding the coh pointer token
              values.prove_exact_nft(
                coh_lock_value,
                currency_symbol,
                coh_pointer_token_name,
              )?,
              // do the this_tx meet the threshold
              tx.total_token_amount(
                inputs,
                action_pid,
                action_tkn,
                coh_mint_threshold,
              )?,
            }
          }
          // anything else fail
          _ -> fail @"Not Verifying Test"
        }
      }
      // burn the poh token
      BurnCoHToken -> {
        // the input being spent
        let coh_lock_input: Input = find.input_by_addr(inputs, coh_lock_addr)
        // this value being spent minus the fee
        let coh_lock_value: Value =
          coh_lock_input.output.value
            |> value.merge(value.negate(fee))
        // get the datum from the lock utxo
        expect coh_lock_datum: CoHDatum = data.input_datum(coh_lock_input)
        // // this is endpoint specific so check for the correct redeemer
        expect coh_lock_redeemer: CoHLockRedeemer =
          find.redeemer_by_ref(redeemers, coh_lock_input.output_reference)
        // the user will lose the ada to the vault
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
          query.get_revoke_coh_threshold(ref_data_datum)
        let max_revoke_fee: Int = query.get_coh_revoke_fee(ref_data_datum)
        when coh_lock_redeemer is {
          //
          // Revoking a coh means burning the pointer and coh token then 
          // sending the remaining value to the vault. The transaction fee
          // must be less than the maximum fee for revoking a coh.
          //
          Revoke -> and {
              // single script input
              count.single_input_with_bypass(
                inputs,
                coh_lock_addr,
                [vault_addr],
              ),
              // fee must be less then max fee
              reference.is_valid_fee(fee, max_revoke_fee),
              // vault add needs to be called
              is_vault_being_spent,
              // the ada is sent to the vault
              payout.at_least(vault_addr, cont_vault_value, outputs),
              // must mint 1 coh pointer token
              minting.exact(
                mint_list,
                currency_symbol,
                coh_lock_datum.verification.pointer.tkn,
                -1,
              ),
              // must mint 1 coh token
              minting.exact(
                mint_list,
                currency_symbol,
                token_names.coh_token_name,
                -1,
              ),
              // do the this_tx meet the threshold
              tx.total_token_amount(
                inputs,
                action_pid,
                action_tkn,
                coh_revoke_threshold,
              ),
              // data reference must be holding correct token
              values.prove_exact_nft(
                ref_data_input.output.value,
                pointer_pid,
                pointer_tkn,
              ),
            }
          // anything else fail
          _ -> fail @"Incorrect CoH Redeemer"
        }
      }
    }
  }
}
