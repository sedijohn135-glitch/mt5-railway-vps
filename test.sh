#!/bin/sh
# Check of mt5-login.sh: sh test.sh
set -e
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
run() {
    rm -f "$dir/mt5.ini"
    env -i PATH="$PATH" MT5_INI="$dir/mt5.ini" "$@" bash mt5-login.sh 2>/dev/null
    iconv -f UTF-16 -t UTF-8 "$dir/mt5.ini" | tr -d '\r'
}
fail() { echo "FAIL: $1"; exit 1; }

with=$(run MT5_LOGIN=123 MT5_PASSWORD='p%s\w' MT5_SERVER=ICMarketsSC-Demo)
echo "$with" | grep -qx 'Login=123' || fail login
echo "$with" | grep -qx 'Password=p%s\\w' || fail password
echo "$with" | grep -qx 'Server=ICMarketsSC-Demo' || fail server
echo "$with" | grep -qx 'Enabled=1' || fail algo-trading
[ "$(head -c 2 "$dir/mt5.ini" | od -An -tx1 | tr -d ' ')" = fffe ] || fail bom

without=$(run MT5_LOGIN=123)
if echo "$without" | grep -q 'Login='; then fail "login written without a password"; fi
echo "$without" | grep -qx 'AllowLiveTrading=1' || fail algo-trading-without-login
echo ok
