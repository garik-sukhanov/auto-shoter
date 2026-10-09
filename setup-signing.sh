#!/bin/bash
# Создаёт локальный самоподписанный сертификат для подписи AutoShoter.
#
# Зачем: без него сборка подписывается ad-hoc, требование подписи привязывается
# к хэшу бинарника, и после каждой пересборки macOS считает приложение новым —
# разрешение на запись экрана слетает. С сертификатом требование выглядит как
#   identifier "me.garik.autoshoter" and certificate root = H"..."
# и остаётся прежним от сборки к сборке.
#
# Пароль от Mac не требуется: настройки доверия не меняются, codesign работает
# и с недоверенным сертификатом.
set -euo pipefail

NAME="AutoShoter Local Signing"

if security find-identity -p codesigning 2>/dev/null | grep -q "$NAME"; then
    echo "Сертификат «$NAME» уже есть."
    security find-identity -p codesigning | grep "$NAME"
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/req.cnf" <<CNF
[req]
distinguished_name = dn
x509_extensions    = v3
prompt             = no

[dn]
CN = $NAME
O  = Local Development

[v3]
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
subjectKeyIdentifier = hash
CNF

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/req.cnf" 2>/dev/null

# Apple Security не понимает современный по умолчанию PKCS12 из LibreSSL — просим legacy.
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -name "$NAME" -passout pass:autoshoter \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 2>/dev/null

security import "$TMP/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P autoshoter -A

echo "Готово. Теперь ./build.sh будет подписывать этим сертификатом."
security find-identity -p codesigning | grep "$NAME"
