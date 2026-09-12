#!/bin/sh
set -e

# Patch firebase-ios-sdk to avoid kSecUseDataProtectionKeychain on macOS.
# On macOS, Apple Data Protection Keychain strictly requires an Apple Developer
# provisioning profile and Keychain Access Groups. For ad-hoc signed binaries,
# SecItemAdd returns OSStatus -34018 unless kSecUseDataProtectionKeychain is omitted.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/build/macos/SourcePackages/checkouts/firebase-ios-sdk/FirebaseAuth/Sources/Swift"

if [ -d "$TARGET_DIR" ]; then
  KEYCHAIN_FILE="$TARGET_DIR/Storage/AuthKeychainServices.swift"
  if [ -f "$KEYCHAIN_FILE" ]; then
    if grep -q "query\[kSecUseDataProtectionKeychain as String\] = true" "$KEYCHAIN_FILE" && ! grep -q "#if !os(macOS)" "$KEYCHAIN_FILE"; then
      sed -i '' 's/query\[kSecUseDataProtectionKeychain as String\] = true/#if !os(macOS)\
    query[kSecUseDataProtectionKeychain as String] = true\
    #endif/' "$KEYCHAIN_FILE"
      echo "[patch_firebase_auth] Patched AuthKeychainServices.swift successfully."
    fi
  fi

  USER_MGR_FILE="$TARGET_DIR/SystemService/AuthStoredUserManager.swift"
  if [ -f "$USER_MGR_FILE" ]; then
    if grep -q "query\[kSecUseDataProtectionKeychain as String\] = true" "$USER_MGR_FILE" && ! grep -q "#if !os(macOS)" "$USER_MGR_FILE"; then
      sed -i '' 's/query\[kSecUseDataProtectionKeychain as String\] = true/#if !os(macOS)\
    query[kSecUseDataProtectionKeychain as String] = true\
    #endif/' "$USER_MGR_FILE"
      echo "[patch_firebase_auth] Patched AuthStoredUserManager.swift successfully."
    fi
  fi
fi
