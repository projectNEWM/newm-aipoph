#!/bin/bash
set -e

# SET UP VARS HERE
source ../.env

# get params
${cli} query protocol-parameters ${network} --out-file ../tmp/protocol.json

# oracle script
poh_lock_script_path="../../contracts/poh_lock_contract.plutus"
poh_lock_script_address=$(${cli} address build --payment-script-file ${poh_lock_script_path} ${network})

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

tx_id_hash=$(jq -r '.tx_id_hash' ../../start_info.json)
tx_id_idx=$(jq -r '.tx_id_idx' ../../start_info.json)
pointer_prefix="5f6169706f70685f"
pointer_pid=$(cat ../../hashes/genesis.hash)
pointer_tkn=$(python3 -c "import sys; sys.path.append('../py/'); from unique_token_name import token_name; token_name('${tx_id_hash}', ${tx_id_idx}, '${pointer_prefix}')")

# asset to trade
cur_rand_num=$(jq -r '.fields[4].fields[1].fields[0].int' ../data/poh/poh-datum.json)
# the locking token information
coloring=$(../py/k-coloring-test/venv/bin/python -c "
import sys;
sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.coloring import find_minimal_coloring;
from src.convert import coloring_to_datum;
g = generate(10, 12, ${cur_rand_num});
c = find_minimal_coloring(g);
print(coloring_to_datum(list(c.values())))")

variable=${coloring}; jq --argjson variable "$variable" '.fields[0].fields[0].list=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json

variable=${coloring}; jq --argjson variable "$variable" '.fields[4].fields[3].fields[0].list=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

graph_hash=$(../py/k-coloring-test/venv/bin/python -c "
import sys;
sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.convert import graph_to_hash;
g = generate(10, 12, ${cur_rand_num});
print(graph_to_hash(g));
")

color_hash=$(../py/k-coloring-test/venv/bin/python -c "
import sys;
sys.path.append('../py/k-coloring-test');
from src.generate import generate;
from src.convert import coloring_to_hash;
from src.coloring import find_minimal_coloring;
g = generate(10, 12, ${cur_rand_num});
c = list(find_minimal_coloring(g).values());
print(coloring_to_hash(c));
")

graph_sig=$(python -c "
import sys;
sys.path.append('../py/data-signing');
from signature import sign;
skey_path = '../wallets/website-wallet/payment.skey';
signature = sign(skey_path, '${graph_hash}');
print(signature)
")

pkh=$(cat ../wallets/website-wallet/payment.vkey)
echo Graph Pkh: $pkh
variable=${pkh}; jq --arg variable "$variable" '.fields[0].fields[1].fields[0].bytes=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json
variable=${pkh}; jq --arg variable "$variable" '.fields[4].fields[3].fields[1].fields[0].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

echo Graph Hash: $graph_hash
variable=${graph_hash}; jq --arg variable "$variable" '.fields[0].fields[1].fields[1].bytes=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json
variable=${graph_hash}; jq --arg variable "$variable" '.fields[4].fields[3].fields[1].fields[1].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

echo Graph Sig: $graph_sig
variable=${graph_sig}; jq --arg variable "$variable" '.fields[0].fields[1].fields[2].bytes=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json
variable=${graph_sig}; jq --arg variable "$variable" '.fields[4].fields[3].fields[1].fields[2].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

color_sig=$(python -c "
import sys;
sys.path.append('../py/data-signing');
from signature import sign;
skey_path = '../wallets/website-wallet/payment.skey';
signature = sign(skey_path, '${color_hash}');
print(signature)
")

echo Color Pkh: $pkh
variable=${pkh}; jq --arg variable "$variable" '.fields[0].fields[2].fields[0].bytes=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json
variable=${pkh}; jq --arg variable "$variable" '.fields[4].fields[3].fields[2].fields[0].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

echo Color Hash: $color_hash
variable=${color_hash}; jq --arg variable "$variable" '.fields[0].fields[2].fields[1].bytes=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json
variable=${color_hash}; jq --arg variable "$variable" '.fields[4].fields[3].fields[2].fields[1].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

echo Color Sig: $color_sig
variable=${color_sig}; jq --arg variable "$variable" '.fields[0].fields[2].fields[2].bytes=$variable' ../data/poh/end-test-redeemer.json > ../data/poh/end-test-redeemer-new.json
mv ../data/poh/end-test-redeemer-new.json ../data/poh/end-test-redeemer.json
variable=${color_sig}; jq --arg variable "$variable" '.fields[4].fields[3].fields[2].fields[2].bytes=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json

variable=1; jq --argjson variable "$variable" '.fields[4].fields[4].int=$variable' ../data/poh/updated-poh-datum.json > ../data/poh/updated-poh-datum-new.json
mv ../data/poh/updated-poh-datum-new.json ../data/poh/updated-poh-datum.json


poh_token="1 ${poh_policy_id}.426567696e205468652050726f6f66204f662048756d616e6974792054657374"

# worst_case_tokens="9223372036854775807 632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b.632e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162b00000000
# + 9223372036854775807 532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c.532e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000
# + 9223372036854775807 432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162d.432e50f13ab4e03c7920e16c35e96758abf4ae966e775df5589b162c00000000"
# min_utxo=$(${cli} transaction calculate-min-required-utxo \
#     --babbage-era \
#     --protocol-params-file ../tmp/protocol.json \
#     --tx-out-inline-datum-file ../data/poh/worst-case-poh-datum.json \
#     --tx-out="${poh_lock_script_address} + 5000000 + ${worst_case_tokens}" | tr -dc '0-9')

# 3 ada for fees and 2 ada for the min utxo for the coh
# required_lovelace=$((${min_utxo} + 3000000 + 2000000 - 1000000 - 500000))

#
#

# get user utxo
echo -e "\033[0;36m Gathering UTxO Information  \033[0m"
${cli} query utxo \
    ${network} \
    --address ${user_address} \
    --out-file ../tmp/user_utxo.json

TXNS=$(jq length ../tmp/user_utxo.json)
if [ "${TXNS}" -eq "0" ]; then
   echo -e "\n \033[0;31m NO UTxOs Found At ${user_address} \033[0m \n";
   exit;
fi
alltxin=""
TXIN=$(jq -r --arg alltxin "" 'keys[] | . + $alltxin + " --tx-in"' ../tmp/user_utxo.json)
user_tx_in=${TXIN::-8}


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

required_lovelace=$(jq -r 'to_entries[].value.value.lovelace' ../tmp/script_utxo.json)
poh_lock_script_out="${poh_lock_script_address} + ${required_lovelace} + ${poh_token}"
echo "Proof of Humanity OUTPUT: "${poh_lock_script_out}

# exit

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

poh_lock_ref_utxo=$(${cli} transaction txid --tx-file ../tmp/utxo-poh_lock_contract.plutus.signed )

echo $collat_tx_in
echo $dao_tx_in
echo $user_tx_in
echo $poh_lock_tx_in
echo $user_address
echo $poh_lock_ref_utxo

slot=$(${cli} query tip ${network} | jq .slot)
current_slot=$(($slot - 1))
final_slot=$(($slot + 250))

echo -e "\033[0;36m Building Tx \033[0m"
FEE=$(${cli} transaction build \
    --babbage-era \
    --out-file ../tmp/tx.draft \
    --invalid-before ${current_slot} \
    --invalid-hereafter ${final_slot} \
    --change-address ${user_address} \
    --read-only-tx-in-reference ${dao_tx_in} \
    --tx-in-collateral ${collat_tx_in} \
    --tx-in ${user_tx_in} \
    --tx-in ${poh_lock_tx_in} \
    --spending-tx-in-reference="${poh_lock_ref_utxo}#1" \
    --spending-plutus-script-v2 \
    --spending-reference-tx-in-inline-datum-present \
    --spending-reference-tx-in-redeemer-file ../data/poh/end-test-redeemer.json \
    --tx-out="${poh_lock_script_out}" \
    --tx-out-inline-datum-file ../data/poh/updated-poh-datum.json \
    --required-signer-hash ${user_pkh} \
    --required-signer-hash ${collat_pkh} \
    ${network})

IFS=':' read -ra VALUE <<< "${FEE}"
IFS=' ' read -ra FEE <<< "${VALUE[1]}"
FEE=${FEE[1]}
echo -e "\033[1;32m Fee: \033[0m" $FEE
#
# exit
#
echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../wallets/user-wallet/payment.skey \
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

cp ../data/poh/updated-poh-datum.json ../data/poh/poh-datum.json