# Release Secrets Setup

One-time setup guide for configuring GitHub Secrets required by the
multi-platform release workflow.

## GitHub Secrets Configuration

Go to: Repository Settings > Secrets and variables > Actions > New repository secret

### App Store Connect API Key

These are shared by both iOS and macOS Fastlane builds for automatic signing
and App Store/TestFlight uploads:

- `APP_STORE_CONNECT_API_KEY_ID` - Key ID from App Store Connect
- `APP_STORE_CONNECT_API_ISSUER_ID` - Issuer ID from App Store Connect
- `APP_STORE_CONNECT_API_KEY_BASE64` - Base64-encoded .p8 private key file

The API key is used with Xcode's `-allowProvisioningUpdates` flag to
automatically download and manage provisioning profiles from Apple's Developer
Portal during CI builds. No separate certificate repository is needed.

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

1. Go to <https://appleid.apple.com>
2. Sign in > App-Specific Passwords > Generate
3. Use the generated password as the secret value

**APPLE_TEAM_ID**

Your Apple Developer Team ID: `8U3RSKF42Q`

### Android Signing

**ANDROID_KEYSTORE_BASE64**

Base64 encode your release keystore:

```bash
base64 -i your-release.keystore | pbcopy
```text
Paste as the secret value.

**ANDROID_KEYSTORE_PASSWORD**

The password for the keystore file.

**ANDROID_KEY_ALIAS**

The alias of the key within the keystore (e.g., `submersion`).

**ANDROID_KEY_PASSWORD**

The password for the key (often the same as the keystore password).

### Beta Pipeline (beta-builds publishing)

**BETA_BUILDS_TOKEN**

Fine-grained personal access token used by the Beta workflow (`beta.yml`) to
publish per-merge beta releases into `submersion-app/beta-builds`:

1. Create at https://github.com/settings/personal-access-tokens/new
2. Resource owner: `submersion-app`
3. Repository access: Only select repositories > `submersion-app/beta-builds`
4. Permissions: Contents - Read and write (nothing else)
5. Set with: `gh secret set BETA_BUILDS_TOKEN --repo submersion-app/submersion`

Rotation: regenerate the token and re-run the same command. The workflow
fails loudly on the next merge to main if the token has expired.

**RELEASE_BOT_TOKEN**

Fine-grained personal access token used by the Promote Beta workflow
(`promote.yml`) to push the version-bump branch and open its auto-merging
PR. A PAT is required because pushes made with the built-in `GITHUB_TOKEN`
never trigger workflows, so CI would not run on the bump branch:

1. Create at https://github.com/settings/personal-access-tokens/new
2. Resource owner: `submersion-app`
3. Repository access: only `submersion-app/submersion`
4. Permissions: Contents - Read and write; Pull requests - Read and write;
   Workflows - Read and write (required to push the stable tag: it points at
   commits whose history touches `.github/workflows`, and GitHub rejects the
   push without this permission)
5. Set with: `gh secret set RELEASE_BOT_TOKEN --repo submersion-app/submersion`

Also requires repository auto-merge to be enabled (Settings > General >
"Allow auto-merge"). Rotation: same as BETA_BUILDS_TOKEN; an expired token
fails the bump-pr job of the next promotion.

## Verification

After configuring all secrets, trigger a test release:

```bash
git tag v0.0.1-test.1
git push origin v0.0.1-test.1
```text
Monitor the workflow in GitHub Actions. If successful, delete the test release:

```bash
git tag -d v0.0.1-test.1
git push origin :refs/tags/v0.0.1-test.1
gh release delete v0.0.1-test.1 --yes
```
