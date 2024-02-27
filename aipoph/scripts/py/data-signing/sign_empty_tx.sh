#!/bin/bash
set -e

# SET UP VARS HERE
source ../../.env

graph_hash="398c36e82ee7a6d7a2bee6fde26fc0c9df373f687b9ec73b5968f9fae8ff92de"

echo -e "\033[0;36m Building Tx \033[0m"
${cli} transaction build-raw \
    --babbage-era \
    --protocol-params-file ../../tmp/protocol.json \
    --out-file ../../tmp/tx-fake.draft \
    --tx-in="${graph_hash}#0" \
    --fee 0

tx=$(cardano-cli transaction txid --tx-file ../../tmp/tx-fake.draft)
echo "Tx Hash:" $tx

echo -e "\033[0;36m Signing \033[0m"
${cli} transaction sign \
    --signing-key-file ../../wallets/user-wallet/payment.skey \
    --tx-body-file ../../tmp/tx-fake.draft \
    --out-file ../../tmp/tx-fake.signed \
    ${network}