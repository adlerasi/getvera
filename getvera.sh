#!/usr/bin/env bash
# Get Vera — tek komut kurulum köprüsü (install.sh'a yönlendirir)
# Kullanim: bash getvera.sh [--all] [--with-opensandbox]
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/install.sh" "$@"
