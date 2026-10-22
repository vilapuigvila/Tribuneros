#!/bin/sh
# Xcode embeds SPM static binary frameworks (Firebase, gRPC) as codeless stubs; App Store Connect still wants a dSYM per stub.
set -eu

for framework in "$ARCHIVE_PATH"/Products/Applications/*.app/Frameworks/*.framework; do
    name=$(basename "$framework" .framework)
    dsym="$ARCHIVE_PATH/dSYMs/$name.framework.dSYM"
    [ -e "$dsym" ] && continue
    xcrun dsymutil "$framework/$name" -o "$dsym" 2>/dev/null || true
done
