#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# oracle script
poh_lock_script_path="../../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

coh_lock_script_path="../../contracts/coh_lock_contract.plutus"
coh_lock_script_address=$(${cli} address build --payment-script-file ${coh_lock_script_path} ${network})

# dao script
dao_script_path="../../contracts/dao_contract.plutus"
dao_script_address=$(${cli} address build --payment-script-file ${dao_script_path} ${network})

# oracle script
oracle_script_path="../../contracts/oracle_contract.plutus"
oracle_script_address=$(${cli} address build --payment-script-file ${oracle_script_path} ${network})

# collat
collat_address=$(cat ../wallets/collat-wallet/payment.addr)
collat_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/collat-wallet/payment.vkey)

# user
user_address=$(cat ../wallets/user-wallet/payment.addr)
user_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/user-wallet/payment.vkey)

# voter
voter_address=$(cat ../wallets/voter-wallet/payment.addr)
voter_pkh=$(${cli} address key-hash --payment-verification-key-file ../wallets/voter-wallet/payment.vkey)

poh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/poh_mint_contract.plutus)
coh_policy_id=$(cardano-cli transaction policyid --script-file ../../contracts/coh_mint_contract.plutus)

tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

poh_token="-1 ${poh_policy_id}.426567696e205468652050726f6f66204f662048756d616e6974792054657374"
coh_token="1 ${coh_policy_id}.436f6e67726174756c6174696f6e732120596f7527726520612068756d616e2e"

# get script utxo
echo -e "\033[0;36m Gathering PoH UTxO Information  \033[0m"
${cli} query utxo \
    --address ${poh_lock_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${poh_lock_script_address} \033[0m \n";
.   exit;
fi
poh_lock_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

echo "PoH Lock UTxO:" $poh_lock_tx_in
string=${poh_lock_tx_in}
IFS='#' read -ra array <<< "$string"

tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")


callable="ca11ab1e"
coh_pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${array[0]}', ${array[1]}, '${callable}')")
coh_pointer_token="1 ${coh_policy_id}.${coh_pointer_tkn}"

min_utxo=$(${cli} transaction calculate-min-required-utxo \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --tx-out-inline-datum-file ../data/coh/coh-datum.json \
    --tx-out="${poh_lock_script_address} + 5000000 + ${coh_token} + ${coh_pointer_token}" | tr -dc '0-9')
echo $min_utxo

mint_token="${coh_token} + ${coh_pointer_token}"

required_lovelace=$(jq -r 'to_entries[].value.value.lovelace' ../tmp/script_utxo.json)
owner_script_out="${user_address} + $((${required_lovelace} - 1000000 - 5000000))"
coh_lock_script_out="${coh_lock_script_address} + 5000000 + ${coh_token} + ${coh_pointer_token}"
echo "Owner OUTPUT: "${owner_script_out}
echo "Certificate of Humanity OUTPUT: "${coh_lock_script_out}
#
# exit
#
echo -e "\033[0;36m Gathering Voter UTxO Information  \033[0m"
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
voter_lovelace_value=$(jq -r '.[].value.lovelace' ../tmp/voter_utxo.json)

voter_out="${voter_address} + $((${voter_lovelace_value} + 1000000)) + 153456789 015d83f25700c83d708fbf8ad57783dc257b01a932ffceac9dcd0c3d.43757272656e6379"
echo "Voter OUTPUT: "${voter_out}


# get script utxo
echo -e "\033[0;36m Gathering DAO UTxO Information  \033[0m"
${cli} query utxo \
    --address ${dao_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${dao_script_address} \033[0m \n";
.   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" --arg policy_id "$pointer_pid" --arg token_name "$pointer_tkn" 'to_entries[] | select(.value.value[$policy_id][$token_name] == 1) | .key | . + $alltxin + " --tx-in"' ../tmp/script_utxo.json)
dao_tx_in=${TXIN::-8}

# get script utxo
echo -e "\033[0;36m Gathering PoH UTxO Information  \033[0m"
${cli} query utxo \
    --address ${poh_lock_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${poh_lock_script_address} \033[0m \n";
.   exit;
fi
poh_lock_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

# get script utxo
echo -e "\033[0;36m Gathering Oracle UTxO Information  \033[0m"
${cli} query utxo \
    --address ${oracle_script_address} \
    ${network} \
    --out-file ../tmp/script_utxo.json
TXNS=$(jq length ../tmp/script_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${oracle_script_address} \033[0m \n";
.   exit;
fi
oracle_tx_in=$(jq -r 'keys[0]' ../tmp/script_utxo.json)

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

cpu_steps=0
mem_steps=0

sale_execution_unts="(${cpu_steps}, ${mem_steps})"

# script reference utxo

poh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_lock_contract.plutus.signed )
poh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_mint_contract.plutus.signed)
coh_mint_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-coh_mint_contract.plutus.signed)

slot=$(${cli} query tip ${network} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 250))

# exit
echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${sale_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/poh/verify-test-redeemer.json \
    --tx-out="${owner_script_out}" \
    --tx-out="${coh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/coh/coh-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token} + ${mint_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-execution-units="${sale_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/burn-redeemer.json \
    --mint-tx-in-reference="${coh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${coh_policy_id}" \
    --mint-reference-tx-in-execution-units="${sale_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/coh/mint-redeemer.json \
    --fee 0

python3 -c "import sys, json; sys.path.append('../py/'); from tx_simulation import from_file; exe_units=from_file('../tmp/tx.draft', False, debug=True);print(json.dumps(exe_units))" > ../data/poh/exe_units.json

cat ../data/poh/exe_units.json
echo poh lock ${poh_lock_tx_in}

exit

plcpu=$(jq -r '.[0].cpu' ../data/poh/exe_units.json)
plmem=$(jq -r '.[0].mem' ../data/poh/exe_units.json)

ocpu=$(jq -r '.[1].cpu' ../data/poh/exe_units.json)
omem=$(jq -r '.[1].mem' ../data/poh/exe_units.json)

pmcpu=$(jq -r '.[2].cpu' ../data/poh/exe_units.json)
pmmem=$(jq -r '.[2].mem' ../data/poh/exe_units.json)


poh_lock_execution_unts="(${plcpu}, ${plmem})"
oracle_execution_unts="(${ocpu}, ${omem})"
poh_mint_execution_unts="(${pmcpu}, ${pmmem})"


FEE=$(${cli} transaction calculate-min-fee --tx-body-file ../tmp/tx.draft ${network} --protocol-params-file ../tmp/protocol.json --tx-in-count 3 --tx-out-count 3 --witness-count 3)
fee=$(echo $FEE | rev | cut -c 9- | rev)

pl_computation_fee=$(echo "0.0000721*${plcpu} + 0.0577*${plmem}" | bc)
o_computation_fee=$(echo "0.0000721*${ocpu} + 0.0577*${omem}" | bc)
pm_computation_fee=$(echo "0.0000721*${pmcpu} + 0.0577*${pmmem}" | bc)

pl_computation_fee_int=$(printf "%.0f" "$pl_computation_fee")
o_computation_fee_int=$(printf "%.0f" "$o_computation_fee")
pm_computation_fee_int=$(printf "%.0f" "$pm_computation_fee")

total_fee=$((${fee} + ${pl_computation_fee_int} + ${o_computation_fee_int} + ${pm_computation_fee_int}))
echo FEE: $total_fee
required_lovelace=$((${min_utxo} + 3000000 + 2000000 - 1000000 - ${total_fee}))
poh_lock_script_out="${poh_lock_script_address} + ${required_lovelace} + ${poh_token}"

${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../tmp/protocol.json \
    --out-file ../tmp/tx.draft \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${poh_lock_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/poh/start-test-redeemer.json \
    --tx-out="${poh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/poh/updated-poh-datum.json \
    --tx-in ${oracle_tx_in} \
    --spending-tx-in-reference="${oracle_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-execution-units="${oracle_execution_unts}" \
    --spending-reference-tx-in-redeemer-file ../data/oracle/oracle-redeemer.json \
    --tx-out="${oracle_script_out}" \
    --tx-out-inline-datum-file ../data/oracle/updated-oracle-datum.json \
    --tx-in ${voter_tx_in} \
    --tx-out="${voter_out}" \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${voter_pkh} \
    --required-signer-hash ${collat_pkh} \
    --mint="${poh_token}" \
    --mint-tx-in-reference="${poh_mint_ref_utxo}#1" \
    --mint-plutus-script-v2 \
    --policy-id="${poh_policy_id}" \
    --mint-reference-tx-in-execution-units="${poh_mint_execution_unts}" \
    --mint-reference-tx-in-redeemer-file ../data/poh/start-test-redeemer.json \
    --fee ${total_fee}


#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/user-wallet/payment.skey \
    --signing-key-file ../wallets/collat-wallet/payment.skey \
    --signing-key-file ../wallets/voter-wallet/payment.skey \
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

cp ../data/poh/updated-poh-datum.json ../data/poh/poh-datum.json
cp ../data/oracle/updated-oracle-datum.json ../data/oracle/oracle-datum.json