# Mekenet Ekub mobile app

This folder contains the Flutter app source. It connects to the Laravel API, so the website and app use the same MySQL data. The app never connects directly to MySQL and does not contain merchant credentials.

The app includes a member dashboard, Ekub search with category and frequency filters, detail cards with Join actions, joined Ekubs with payment and leave actions, payment schedules, and Telebirr checkout. Profile actions are native app screens for editing profile details and photos, KYC, saved payout accounts, password and account settings, two-step verification, Ekub applications, finished Ekubs, privacy, terms, and support. These screens use the same Laravel database as the website. Admin and partner pages remain on the website.

## 1. Start the Laravel backend

Open PowerShell in the Laravel project folder:

```powershell
cd C:\dev\MekenetEkubLaravel
```

Make sure the MySQL service is running. If it is stopped, open `services.msc`, find `MySQL80`, and choose **Start** (run Services as administrator if Windows denies access). Then start Laravel:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

The Laravel website and mobile API use the same database configured for this project. The Sanctum API-token table migration has already been applied here. On another installation, set up its database first and run `php artisan migrate` once.

Keep this PowerShell window open while using the app.

## 2. Install Flutter tools

Install the Flutter SDK and Android Studio on Windows. In PowerShell, add the Flutter SDK `bin` folder to this terminal session (adjust the path if you installed it elsewhere), then confirm:

```powershell
$env:Path = "C:\develop\flutter\bin;$env:Path"
flutter doctor
flutter devices
```

In Android Studio, install the Android SDK and platform tools. On a physical Android phone, enable Developer options and USB debugging, connect the phone by USB, and approve the debugging prompt.

## 3. Create the runnable Flutter project

The source files here are kept separate from Flutter-generated platform files. From the Laravel project folder, run:

```powershell
cd C:\dev\MekenetEkubLaravel
flutter create --org et.mekenet --project-name mekenet_mobile --platforms=android,ios mobile_app_runner
Copy-Item -Path .\mobile_app\lib\* -Destination .\mobile_app_runner\lib -Recurse -Force
Copy-Item -Path .\mobile_app\pubspec.yaml -Destination .\mobile_app_runner\pubspec.yaml -Force
Set-Location .\mobile_app_runner
flutter pub get
```

The app uses `minSdk = 24` for the current image picker dependency. If Flutter generated the Groovy file `android\app\build.gradle`, set `minSdkVersion 24` instead.

For local HTTP testing only, open `android\app\src\main\AndroidManifest.xml` and add `android:usesCleartextTraffic="true"` and `android:allowBackup="false"` to the `<application ...>` tag. When you deploy the website, use an HTTPS URL and remove the local cleartext setting; keep backups disabled so the stored login token is not copied with device backups.

## 4. Run on Android

For the Android emulator, leave Laravel running and use:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is the Android emulator’s address for the Windows host. It is not the right address for a real phone.

For a real Android phone on the same Wi-Fi:

1. Run `ipconfig` on the PC and find its IPv4 address, such as `192.168.1.50`.
2. Allow PHP/Laravel through Windows Firewall on your private network if Windows asks.
3. Run the app with your PC’s address:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

Replace the example IP with the PC’s actual IPv4 address. Both devices must use the same network, and the Laravel server must stay open.

## 5. Use the app

Sign in with an existing **member** account or create a member account. Admin and partner accounts continue using the website. Email OTP or authenticator verification follows the account’s existing security settings. Submit KYC from the Profile tab and wait for approval before joining an Ekub.

Payment checkout opens Telebirr outside the app. This app reports the payment status returned by Laravel; a checkout by itself is not proof of settlement. A payment stays pending until the merchant callback/settlement verification is configured or an admin reviews it.

## iPhone

The Flutter source targets iOS too, but building or running it on an iPhone requires a Mac with Xcode. Create or copy the Flutter project on that Mac, run `flutter pub get`, and use a reachable HTTPS backend URL for device testing. Windows can prepare the shared Dart source and Android app, but cannot build the iOS app.

## API overview

The app calls these authenticated Laravel endpoints under `/api/v1`:

- `POST auth/register`, `POST auth/login`, `POST auth/2fa/verify`, `POST auth/2fa/resend`
- `GET me`, `GET ekubs`, `GET ekubs/{id}`, `POST ekubs/{id}/join`, `DELETE ekubs/{id}/leave`
- `GET my/ekubs`, `GET my/status`, `POST payments/{ekub}/{period}/telebirr`
- `POST profile`, `POST profile/picture`, `GET/POST profile/payment-methods`, `GET/POST profile/applications`, `GET profile/finished-ekubs`
- `GET/POST profile/kyc`, `GET profile/security`, `POST profile/security/{action}`, `POST profile/password`, `POST profile/account/delete`

Laravel Sanctum issues a revocable, 30-day bearer token after sign-in. The app stores that token using the platform secure-storage facility. All app data remains in the existing Laravel/MySQL database.

