# Codemagic App Store Connect Setup

The root `codemagic.yaml` workflow builds a signed IPA and uploads it to App Store Connect. It does not automatically submit the build for external TestFlight review or App Store review.

## 1. Prepare Apple

1. Register the final bundle identifier in the Apple Developer portal.
2. Create the app record in App Store Connect using the same bundle identifier.
3. In App Store Connect, open **Users and Access > Integrations > App Store Connect API**.
4. Create an API key with **App Manager** access. Download the `.p8` file and record its Key ID and Issuer ID.
5. Copy the numeric Apple ID from the app's **General > App Information** page.

## 2. Add Codemagic variables

In Codemagic, open the application and add these encrypted variables to a group named `appstore_credentials`:

- `APP_STORE_CONNECT_PRIVATE_KEY`: complete contents of the downloaded `.p8` file
- `APP_STORE_CONNECT_KEY_IDENTIFIER`: App Store Connect API Key ID
- `APP_STORE_CONNECT_ISSUER_ID`: App Store Connect Issuer ID
- `CERTIFICATE_PRIVATE_KEY`: PEM private key used to create or fetch the distribution certificate

Add these variables to a group named `ios_config`:

- `APPLE_TEAM_ID`: 10-character Apple Developer Team ID
- `APP_STORE_APPLE_ID`: numeric App Store Connect Apple ID

The bundle identifier is fixed to `com.crownx.game` in both the Xcode configuration and `codemagic.yaml`.

To create `CERTIFICATE_PRIVATE_KEY` locally, run:

```sh
openssl genrsa -out ios_distribution_private_key 2048
cat ios_distribution_private_key | pbcopy
```

Paste the copied PEM value into Codemagic as an encrypted variable. Do not commit the private key or `.p8` file.

## 3. Connect the repository

1. Push this project, including `codemagic.yaml`, to GitHub, GitLab or Bitbucket.
2. In Codemagic, choose **Add application** and connect that repository.
3. Select **Codemagic YAML** configuration.
4. Start the `Catch the Jewels - App Store Connect` workflow.

After a successful workflow, the IPA appears in App Store Connect and begins Apple processing. When processing finishes, assign it to internal TestFlight testers or select it for the App Store version.

## 4. Before App Store review

- Complete App Privacy using the StorageQuotaManager and Adjust disclosures.
- Add the privacy policy URL, support URL, category, age rating and screenshots.
- Test the archived build on a physical device.
- Keep `submit_to_app_store: false` until the App Store listing is complete.
