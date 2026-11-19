#!/usr/bin/env bash
# Deploys to testnet and writes deployments/testnet.json.
# Needs stellar identities (env overridable): ADMIN, ARBITER, TREASURY, RELAYER.
# Also needs TESTNET_USDC (SAC contract id, verify from Circle/Stellar docs first).
# Init parameters are env overridable too; defaults are the values this script has always used.
# See README.md ("Deploying your own") for the list.
set -euo pipefail
cd "$(dirname "$0")/.."
# Refuse before deploying anything: a second deploy would orphan the recorded contract.
RECORD=deployments/testnet.json
if [ -f "$RECORD" ] && [ "${OVERWRITE_DEPLOYMENT:-}" != "1" ]; then
  echo "refusing to overwrite $RECORD: $(cat "$RECORD")" >&2
  echo "set OVERWRITE_DEPLOYMENT=1 to deploy a new contract and replace that record" >&2
  exit 1
fi
ADMIN=${ADMIN:-se-testnet-admin}; ARBITER=${ARBITER:-se-testnet-arbiter}
TREASURY=${TREASURY:-se-testnet-treasury}; RELAYER=${RELAYER:-se-testnet-relayer}
TESTNET_USDC=${TESTNET_USDC:-}  # optional: verify the USDC SAC id from Circle/Stellar docs first
FEE_BPS=${FEE_BPS:-300}
GRACE_SECS=${GRACE_SECS:-259200}
MIN_DURATION_SECS=${MIN_DURATION_SECS:-86400}
MAX_DURATION_SECS=${MAX_DURATION_SECS:-7776000}
TOKEN_MIN=${TOKEN_MIN:-10000000}
TOKEN_MAX=${TOKEN_MAX:-5000000000}
./scripts/build.sh
W=target/wasm32v1-none/release/bounty_escrow.wasm
echo "effective testnet parameters:"
echo "  fee_bps=$FEE_BPS grace_secs=$GRACE_SECS min_duration_secs=$MIN_DURATION_SECS max_duration_secs=$MAX_DURATION_SECS"
echo "  token min=$TOKEN_MIN max=$TOKEN_MAX"
echo "  usdc=${TESTNET_USDC:-<unset>} admin=$ADMIN arbiter=$ARBITER treasury=$TREASURY relayer=$RELAYER"
ID=$(stellar contract deploy --wasm "$W" --source "$ADMIN" --network testnet)
addr() { stellar keys address "$1"; }
stellar contract invoke --id "$ID" --source "$ADMIN" --network testnet -- init \
  --admin "$(addr "$ADMIN")" --relayer "$(addr "$RELAYER")" --arbiter "$(addr "$ARBITER")" \
  --treasury "$(addr "$TREASURY")" --fee_bps "$FEE_BPS" --grace_secs "$GRACE_SECS" \
  --min_duration_secs "$MIN_DURATION_SECS" --max_duration_secs "$MAX_DURATION_SECS"
NATIVE=$(stellar contract id asset --asset native --network testnet)
for T in ${TESTNET_USDC:+"$TESTNET_USDC"} "$NATIVE"; do
  stellar contract invoke --id "$ID" --source "$ADMIN" --network testnet -- set_token \
    --admin "$(addr "$ADMIN")" --token "$T" --min "$TOKEN_MIN" --max "$TOKEN_MAX"
done
mkdir -p deployments
printf '{"network":"testnet","contract_id":"%s"}\n' "$ID" > deployments/testnet.json
echo "contract: $ID"
