#!/usr/bin/env bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# coh lock script
coh_lock_script_path="../../contracts/coh_lock_contract.plutus"
coh_lock_script_address=$(${cli} address build --payment-script-file ${coh_lock_script_path} ${network})

# reference script
reference_script_path="../../contracts/reference_contract.plutus"
reference_script_address=$(${cli} address build --payment-script-file ${reference_script_path} ${network})

# vault script
vault_script_path="../../contracts/vault_contract.plutus"
vault_script_address=$(${cli} address build --payment-script-file ${vault_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# voter
voter_address=$(cat ../wallets/voter-wallet/payment.addr)
voter_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/voter-wallet/payment.vkey)

# coh token information
coh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/coh_mint_contract.plutus)
coh_token_name=$(jq -r '.coh_token_name' ../../config.json)
coh_token="-1 ${coh_policy_id}.${coh_token_name}"
# coh token information
coh_pointer_tkn=$(cat ../data/coh/coh-token.name)
coh_pointer_token="-1 ${coh_policy_id}.${coh_pointer_tkn}"

# the genesis pointer token information
tx_id_hash=$(jq -r '.tx_id_hash' ../../config.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../config.json)
pointer_prefix=$(jq -r '.pointer_prefix' ../../config.json)
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

#
# exit
#
# get user utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${voter_address} \
    --out-file ../tmp/voter_utxo.json

TXNS=$(jq length ../tmp/voter_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${voter_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/voter_utxo.json)
voter_tx_in=${TXIN::-8}
echo Voter UTxO: ${voter_tx_in}
voter_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/voter_utxo.json)

# voter sends teh action token back and gets the incentive token
action_pid=$(jq -r '.action_pid' ../../config.json)
action_tkn=$(jq -r '.action_tkn' ../../config.json)
action_amt=$(jq -r --arg action_pid "$action_pid" --arg action_tkn "$action_tkn" '.[].value[$action_pid][$action_tkn]' ../tmp/voter_utxo.json)

voter_out="${voter_address} + ${voter_lovelace_value} + ${action_amt} ${action_pid}.${action_tkn}"
echo "Voter OUTPUT: "${voter_out}

# get script utxo
echo -e "\033[0;36m Gathering CoH UTxO Information  \033[0m"
${cli} query utxo \
    --address ${coh_lock_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${coh_lock_script_address} \033[0m \n";
.   exit;
fi
coh_lock_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)
echo CoH UTxO: ${coh_lock_tx_in}
coh_lock_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/script_utxo.json)
echo Current CoH Lovelace: ${coh_lock_lovelace_value}

# get reference script utxo
echo -e "\033[0;36m Gathering Reference UTxO Information  \033[0m"
${cli} query utxo \
    --address ${reference_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${reference_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
reference_tx_in=${TXIN::-8}

# get vault script utxo
echo -e "\033[0;36m Gathering Vault UTxO Information  \033[0m"
${cli} query utxo \
    --address ${vault_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${vault_script_address} \033[0m \n";
.   exit;
fi
vault_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)
echo Vault UTxO: ${vault_tx_in}
# update teh vault add redeemer with the coh lock lovelace value
variable=${coh_lock_lovelace_value}; jq --argjson variable "$variable" '.fields[0].list[0].fields[2].int=$variable' ../data/vault/add-redeemer.json | sponge ../data/vault/add-redeemer.json

vault_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/script_utxo.json)
vault_script_out="${vault_script_address} + $((${vault_lovelace_value} + ${coh_lock_lovelace_value}))"
echo "Vault OUTPUT: "${vault_script_out}

# exit

# collat info
echo -e "\033[0;36m Gathering Collateral UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${collat_address} \
    --out-file ../tmp/collat_utxo.json

TXNS=$(jq length ../tmp/collat_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${collat_address} \033[0m \n";
   exit;
fi
collat_tx_in=$(jq -r 'keys[0]' ../tmp/collat_utxo.json)


# script reference utxo
coh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-coh_lock_contract.plutus.signed )
coh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-coh_mint_contract.plutus.signed)
vault_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-vault_contract.plutus.signed)

cpu_steps=0
mem_steps=0

execution_units="(${cpu_steps}, ${mem_steps})"

echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --read-only-tx-in-reference ${reference_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${coh_lock_tx_in} \
    --spending-tx-in-reference="${coh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_units}" \
    --spending-reference-tx-in-redeemer-file ../data/coh/revoke-redeemer.json \
    --tx-in ${vault_tx_in} \
    --spending-tx-in-reference="${vault_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${execution_units}" \
    --spending-reference-tx-in-redeemer-file ../data/vault/add-redeemer.json \
    --tx-out="${vault_script_out}" \
    --tx-out-inline-datum-file ../data/vault/vault-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${coh_token} + ${coh_pointer_token}" \
    --mint-tx-in-reference="${coh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${coh_policy_id}" \
    --mint-reference-tx-in-execution-units="${execution_units}" \
    --mint-reference-tx-in-redeemer-file ../data/coh/burn-redeemer.json \
    --fee 0

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False, debug=False);print(json.dumps(exe_units))" > ../data/coh/exe_units.json

cat ../data/coh/exe_units.json
if [ "$(cat ../data/coh/exe_units.json)" = '[{}]' ]; then
    echo "Validation Failed."
    exit 1
else
    echo "Validation Success."
fi

o_index=$(python3 -c "import sys; sys.path.append('../py/'); from lexico_order import compare_strings; x = compare_strings('${coh_lock_tx_in}', '${vault_tx_in}'); print(x)")
coh_index=$((${o_index}))
vault_index=$((1 + ${o_index}))

# coh lock
clcpu=$(jq -r --argjson index "$coh_index" '.[$index].cpu' ../data/coh/exe_units.json)
clmem=$(jq -r --argjson index "$coh_index" '.[$index].mem' ../data/coh/exe_units.json)

# vault
vcpu=$(jq -r --argjson index "$vault_index" '.[$index].cpu' ../data/coh/exe_units.json)
vmem=$(jq -r --argjson index "$vault_index" '.[$index].mem' ../data/coh/exe_units.json)

# coh mint
cmcpu=$(jq -r '.[2].cpu' ../data/coh/exe_units.json)
cmmem=$(jq -r '.[2].mem' ../data/coh/exe_units.json)

coh_lock_execution_units="(${clcpu}, ${clmem})"
vault_execution_units="(${vcpu}, ${vmem})"
coh_mint_execution_units="(${cmcpu}, ${cmmem})"

FEE=$(${cli} transaction calculate-min-fee --tx-body-file ../tmp/tx.draft ${network} --protocol-params-file ../tmp/protocol.json --tx-in-count 3 --tx-out-count 3 --witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)

cl_computation_fee=$(echo "0.0000721*${clcpu} + 0.0577*${clmem}" | bc)
vault_computation_fee=$(echo "0.0000721*${vcpu} + 0.0577*${vmem}" | bc)
coh_computation_fee=$(echo "0.0000721*${cmcpu} + 0.0577*${cmmem}" | bc)

cl_computation_fee_int=$(printf "%.0f" "$cl_computation_fee")
vault_computation_fee_int=$(printf "%.0f" "$vault_computation_fee")
coh_computation_fee_int=$(printf "%.0f" "$coh_computation_fee")

total_fee=$((${fee} + ${cl_computation_fee_int} + ${vault_computation_fee_int} + ${coh_computation_fee_int}))
echo FEE: $total_fee

# update teh vault add redeemer with the coh lock lovelace value
variable=$((${coh_lock_lovelace_value} - ${total_fee})); jq --argjson variable "$variable" '.fields[0].list[0].fields[2].int=$variable' ../data/vault/add-redeemer.json | sponge ../data/vault/add-redeemer.json

vault_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/script_utxo.json)
vault_script_out="${vault_script_address} + $((${vault_lovelace_value} + ${coh_lock_lovelace_value} - ${total_fee}))"
echo "Vault OUTPUT: "${vault_script_out}

echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --read-only-tx-in-reference ${reference_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${coh_lock_tx_in} \
    --spending-tx-in-reference="${coh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${coh_lock_execution_units}" \
    --spending-reference-tx-in-redeemer-file ../data/coh/revoke-redeemer.json \
    --tx-in ${vault_tx_in} \
    --spending-tx-in-reference="${vault_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${vault_execution_units}" \
    --spending-reference-tx-in-redeemer-file ../data/vault/add-redeemer.json \
    --tx-out="${vault_script_out}" \
    --tx-out-inline-datum-file ../data/vault/vault-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${coh_token} + ${coh_pointer_token}" \
    --mint-tx-in-reference="${coh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${coh_policy_id}" \
    --mint-reference-tx-in-execution-units="${coh_mint_execution_units}" \
    --mint-reference-tx-in-redeemer-file ../data/coh/burn-redeemer.json \
    --fee ${total_fee}

#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/voter-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --tx-body-file ../tmp/tx.draft \
    --out-file ../tmp/tx.signed \
    ${network}
#
# exit
#
echo -e "\033[0;36m Submitting \033[0m"
${cli} transaction submit \
    ${network} \
    --tx-file ../tmp/tx.signed

tx=$(cardano-cli transaction txid --tx-file ../tmp/tx.signed)
echo "Tx Hash:" $tx
