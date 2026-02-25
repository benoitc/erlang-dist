#!/bin/bash
# Test Erlang installation
# Usage: ./test-install.sh [ERL_PATH]

set -e

ERL="${1:-erl}"
ERLC="${ERL%erl}erlc"
ESCRIPT="${ERL%erl}escript"

echo "=== Erlang Installation Test ==="
echo ""

# Test erl command exists
echo "1. Testing erl command..."
if ! command -v "$ERL" >/dev/null 2>&1; then
    echo "FAIL: erl command not found"
    exit 1
fi
echo "   PASS: erl found at $(command -v "$ERL")"

# Test OTP version
echo ""
echo "2. Testing OTP version..."
OTP_RELEASE=$("$ERL" -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' -noshell)
echo "   OTP Release: $OTP_RELEASE"

# Test system info
echo ""
echo "3. System Information..."
"$ERL" -eval '
    io:format("   ERTS Version: ~s~n", [erlang:system_info(version)]),
    io:format("   Word Size: ~p bits~n", [erlang:system_info(wordsize) * 8]),
    io:format("   SMP: ~p~n", [erlang:system_info(smp_support)]),
    io:format("   Threads: ~p~n", [erlang:system_info(threads)]),
    io:format("   Async Threads: ~p~n", [erlang:system_info(thread_pool_size)]),
    halt().
' -noshell

# Test erlc
echo ""
echo "4. Testing erlc..."
if command -v "$ERLC" >/dev/null 2>&1; then
    ERLC_VERSION=$("$ERLC" -v 2>&1 || echo "unknown")
    echo "   PASS: erlc works"
else
    echo "   FAIL: erlc not found"
    exit 1
fi

# Test escript
echo ""
echo "5. Testing escript..."
if command -v "$ESCRIPT" >/dev/null 2>&1; then
    echo "   PASS: escript found"
else
    echo "   FAIL: escript not found"
    exit 1
fi

# Test crypto application
echo ""
echo "6. Testing crypto application..."
"$ERL" -eval '
    case application:ensure_all_started(crypto) of
        {ok, _} ->
            io:format("   PASS: crypto started~n"),
            io:format("   Crypto info: ~p~n", [crypto:info_lib()]);
        {error, Reason} ->
            io:format("   FAIL: crypto failed: ~p~n", [Reason]),
            halt(1)
    end,
    halt().
' -noshell

# Test SSL application
echo ""
echo "7. Testing ssl application..."
"$ERL" -eval '
    case application:ensure_all_started(ssl) of
        {ok, _} ->
            io:format("   PASS: ssl started~n"),
            Versions = ssl:versions(),
            io:format("   TLS versions: ~p~n", [proplists:get_value(available, Versions)]);
        {error, Reason} ->
            io:format("   FAIL: ssl failed: ~p~n", [Reason]),
            halt(1)
    end,
    halt().
' -noshell

# Test public_key application
echo ""
echo "8. Testing public_key application..."
"$ERL" -eval '
    case application:ensure_all_started(public_key) of
        {ok, _} ->
            io:format("   PASS: public_key started~n");
        {error, Reason} ->
            io:format("   FAIL: public_key failed: ~p~n", [Reason]),
            halt(1)
    end,
    halt().
' -noshell

# Test compiler
echo ""
echo "9. Testing compilation..."
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/test_module.erl" << 'EOF'
-module(test_module).
-export([hello/0, add/2]).

hello() -> "Hello from Erlang!".
add(A, B) -> A + B.
EOF

"$ERLC" -o "$TMPDIR" "$TMPDIR/test_module.erl"
if [ -f "$TMPDIR/test_module.beam" ]; then
    echo "   PASS: Module compiled successfully"
else
    echo "   FAIL: Compilation failed"
    exit 1
fi

# Test running compiled module
echo ""
echo "10. Testing compiled module execution..."
"$ERL" -pa "$TMPDIR" -eval '
    io:format("   ~s~n", [test_module:hello()]),
    Result = test_module:add(2, 3),
    case Result of
        5 -> io:format("   PASS: 2 + 3 = ~p~n", [Result]);
        _ -> io:format("   FAIL: Expected 5, got ~p~n", [Result]), halt(1)
    end,
    halt().
' -noshell

# Test inets/httpc (optional, may not be available)
echo ""
echo "11. Testing inets application..."
"$ERL" -eval '
    case application:ensure_all_started(inets) of
        {ok, _} ->
            io:format("   PASS: inets started~n");
        {error, Reason} ->
            io:format("   WARN: inets failed: ~p~n", [Reason])
    end,
    halt().
' -noshell

# Summary
echo ""
echo "=== All Tests Passed ==="
echo "Erlang/OTP $OTP_RELEASE is installed and working correctly."
