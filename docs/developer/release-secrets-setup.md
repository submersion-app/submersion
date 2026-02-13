# Release Secrets Setup

One-time setup guide for configuring GitHub Secrets required by the
multi-platform release workflow.

## GitHub Secrets Configuration

Go to: Repository Settings > Secrets and variables > Actions > New repository secret

### Already Configured (iOS)

These should already exist from the iOS release workflow:

- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `MATCH_PASSWORD`
- `MATCH_GIT_BASIC_AUTHORIZATION`

### macOS Signing (Developer ID DMG)

**MACOS_CERTIFICATE_BASE64**

Export your Developer ID Application certificate from Keychain Access:

1. Open Keychain Access
2. Find "Developer ID Application: [Your Name]"
3. Right-click > Export Items > save as .p12
4. Set a password when prompted
5. Base64 encode: `base64 -i certificate.p12 | pbcopy`
6. Paste as the secret value

**MACOS_CERTIFICATE_PASSWORD**

The password you set when exporting the .p12 file.

**MACOS_KEYCHAIN_PASSWORD**

Any arbitrary password (e.g., `ci-keychain-password`). Only used to create a
temporary keychain in CI.

### macOS Notarization

**APPLE_ID**

Your Apple ID email address (e.g., `ericgriffin@gmail.com`).

**APPLE_APP_PASSWORD**

Generate an app-specific password:

1. Go to https://appleid.apple.com
2. Sign in > App-Specific Passwords > Generate
3. Use the generated password as the secret value

**APPLE_TEAM_ID**

Your Apple Developer Team ID: `8U3RSKF42Q`

### Android Signing

**ANDROID_KEYSTORE_BASE64**

Base64 encode your release keystore:

```bash
base64 -i your-release.keystore | pbcopy
```

Paste as the secret value.

**ANDROID_KEYSTORE_PASSWORD**

The password for the keystore file.

**ANDROID_KEY_ALIAS**

The alias of the key within the keystore (e.g., `submersion`).

**ANDROID_KEY_PASSWORD**

The password for the key (often the same as the keystore password).

## macOS Match Setup

If macOS provisioning profiles have not been added to your Match repository yet:

```bash
cd macos
bundle install
bundle exec fastlane match appstore --platform macos
```

This will generate Mac App Store certificates and provisioning profiles and
store them encrypted in your certificates repository.

## Verification

After configuring all secrets, trigger a test release:

```bash
git tag v0.0.1-test.1
git push origin v0.0.1-test.1
```

Monitor the workflow in GitHub Actions. If successful, delete the test release:

```bash
git tag -d v0.0.1-test.1
git push origin :refs/tags/v0.0.1-test.1
gh release delete v0.0.1-test.1 --yes
```
