#!/usr/bin/env bash
#
# Creates a stable, self-signed code-signing identity in your login keychain so
# macOS remembers Prism's Screen Recording permission across rebuilds.
#
# Why: an ad-hoc signature's "designated requirement" is just the binary hash,
# which changes on every build — so TCC treats each build as a brand-new app and
# re-asks for permission. A stable identity fixes that. Run this ONCE:
#
#   ./Tools/setup-signing.sh
#
set -euo pipefail

IDENTITY="${1:-Prism Local Signing}"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning 2>/dev/null | grep -q "$IDENTITY"; then
    echo "✓ Signing identity '$IDENTITY' already exists — nothing to do."
    exit 0
fi

echo "▸ Creating self-signed code-signing identity '$IDENTITY'…"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cfg" <<CFG
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $IDENTITY
[ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
CFG

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cfg" 2>/dev/null

# -legacy is needed for OpenSSL 3 (Homebrew); macOS LibreSSL rejects it, so fall back.
openssl pkcs12 -export -legacy -out "$TMP/id.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$IDENTITY" -passout pass:prism 2>/dev/null \
  || openssl pkcs12 -export -out "$TMP/id.p12" \
    -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$IDENTITY" -passout pass:prism 2>/dev/null

# -A authorizes any app (incl. codesign) to use the key without a GUI prompt.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P prism -A -T /usr/bin/codesign >/dev/null

echo "✓ Created '$IDENTITY'."
echo "  Rebuild with ./build.sh — it will sign with this identity automatically."
echo "  Grant Screen Recording one more time (the identity changed); it sticks after that."
