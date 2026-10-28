# iOS Native Project SDK Integration Guide

## Integration Updates

- Link the `Security` framework because the SDK uses Keychain APIs.
- **Adjust SDK dependency is required for this SDK delivery**: This SDK build includes Adjust support. You must add Adjust SDK to your project via Swift Package Manager:
  - Repository: `https://github.com/adjust/ios_sdk`
  - Version: **5.4.0** to **5.6.2**
  - Select **AdjustSdk** product
  - Reference: https://dev.adjust.com/en/sdk/ios

## Required Configuration for This Delivery

Complete every item below before submitting your build. Each line lists a configuration the SDK requires from the host app and the H5 bridges it unlocks.

### 1. Linker flag (Required)

Target → Build Settings → **Other Linker Flags** → add `-ObjC`. Without it, the static library is linked but the SDK's startup code never runs.

### 2. Info.plist keys

**SKAdNetworkItems (Required, copy the complete block as-is)**

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict><key>SKAdNetworkIdentifier</key><string>v9wttpbfk9.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>n38lu8286q.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>mj797d8u6f.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>22mmun2rn5.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>238da6jt44.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>899vrgt9g8.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>ludvb6z3bs.skadnetwork</string></dict>
    <dict><key>SKAdNetworkIdentifier</key><string>x8jxxk4ff5.skadnetwork</string></dict>
</array>
```

The following keys are optional:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

`NSPhotoLibraryAddUsageDescription` is optional and is only needed when the app uses the `saveBase64PNG` H5 bridge. Omitting it does not affect core SDK functionality.

### 3. Orientation (Required)

Target → General → **Deployment Info** → check both **Portrait** and **Landscape** (or list them under `UISupportedInterfaceOrientations`). The `setOrientation` H5 bridge can only lock to orientations the host app declares as supported.

### 4. System frameworks

Target → Build Phases → **Link Binary With Libraries**:

- `Security` (Keychain), `libc++.tbd` — always required
- `StoreKit` — used by the SDK to update SKAdNetwork conversion values, which the system mirrors to AdAttributionKit. The static library adds the linker directive automatically, so adding it manually is optional. If you add it in Xcode, keep its status **Required**; StoreKit is available on every supported iOS version (iOS 15+).
- `AppTrackingTransparency` optional
- `Social` — optional
- `AdSupport`, `AdServices` — optional

### 5. Swift Package Manager dependencies (Required)

- **Adjust** (only for Adjust-enabled deliveries — confirm with the delivery note):
  `https://github.com/adjust/ios_sdk`, **5.4.0** to **5.6.2**, product **AdjustSdk**

> The host app still needs to add the actual Adjust Swift package above so the symbols are present at link and runtime.

### 6. Splash animation gated on the network authorization notification (Required)

The host app must display a splash animation at launch and keep it visible until the SDK reports the network authorization result. Once iOS has determined whether network access is allowed, the SDK posts one of the following notifications via `NSNotificationCenter` on the main thread:

- `network_allowed` — network authorization granted (network path is satisfied)
- `network_denied` — network authorization denied (network path is not satisfied)

Rules for the host app:

1. Register observers for **both** notification names before showing the splash animation. Whichever arrives first determines the result; only one of them will be delivered per state change.
2. When either notification arrives, keep the splash animation for an additional **0.5 seconds**, then end it.
3. If neither notification arrives within **5 seconds** of the splash animation starting, end the animation anyway — never wait indefinitely.
4. Remove both observers once the splash animation ends.

Both notifications carry no `object` or `userInfo` payload.

**Swift**

```swift
private var splashEnded = false
private var splashStartDate = Date()

func showSplash() {
    splashStartDate = Date()
    let center = NotificationCenter.default
    center.addObserver(self, selector: #selector(onNetworkAuthorizationResult),
                       name: NSNotification.Name("network_allowed"), object: nil)
    center.addObserver(self, selector: #selector(onNetworkAuthorizationResult),
                       name: NSNotification.Name("network_denied"), object: nil)

    // Hard cap: end the splash after 5 seconds even without a notification.
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
        self?.endSplash()
    }
}

@objc private func onNetworkAuthorizationResult() {
    // Keep the animation for 0.5 more seconds after the result arrives.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
        self?.endSplash()
    }
}

private func endSplash() {
    guard !splashEnded else { return }
    splashEnded = true
    let center = NotificationCenter.default
    center.removeObserver(self, name: NSNotification.Name("network_allowed"), object: nil)
    center.removeObserver(self, name: NSNotification.Name("network_denied"), object: nil)
    // Stop and remove the splash animation here.
}
```

**Objective-C**

```objc
- (void)showSplash {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(onNetworkAuthorizationResult)
                   name:@"network_allowed" object:nil];
    [center addObserver:self selector:@selector(onNetworkAuthorizationResult)
                   name:@"network_denied" object:nil];

    // Hard cap: end the splash after 5 seconds even without a notification.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf endSplash];
    });
}

- (void)onNetworkAuthorizationResult {
    // Keep the animation for 0.5 more seconds after the result arrives.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [weakSelf endSplash];
    });
}

- (void)endSplash {
    if (self.splashEnded) { return; }
    self.splashEnded = YES;
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:@"network_allowed" object:nil];
    [center removeObserver:self name:@"network_denied" object:nil];
    // Stop and remove the splash animation here.
}
```

---

## 1. SDK Resources

The library file name varies per client, but the call logic and functionality remain the same.

Delivery directory structure:

```
domain.example.com/
├── dist/                        # For real device and App Store submission
│   └── libYourSDKName.a         # Static library
└── distSimulator/               # For simulator debugging (loads a webview to verify integration)
    └── libYourSDKName.a
```

> A header file may also appear under `include/` in some deliveries. It is not required and should not be imported.

## 2. Add the SDK to Your Project

1. Drag `libYourSDKName.a` into the Xcode project navigator (recommended: place it under a `Libs/` folder).
2. In the dialog, check **Copy items if needed** and confirm the target is selected.
3. Go to Target → **Build Phases** → **Link Binary With Libraries** and confirm `libYourSDKName.a` is listed.
4. In the same **Link Binary With Libraries** section, click `+`, search for `libc++.tbd`, and add it.
5. Go to Target → **Build Settings** → **Other Linker Flags**.
6. Add `-ObjC`. If the setting already has values, keep them and add `-ObjC` as an additional item.

> `-ObjC` is mandatory. It forces Objective-C object files from the static library to be loaded so the SDK's automatic startup code can run.

## 3. Notes

1. **Orientation**: The app must declare all orientations it wishes the SDK to be able to lock to (Portrait / Landscape). The SDK will only switch between orientations the host app supports.
2. **Deployment Target**: iOS 15.0 or later is required; iOS 16.0 or later is recommended.
