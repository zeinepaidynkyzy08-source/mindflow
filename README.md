# MindFlow

MindFlow is a Flutter app for students who feel overloaded by deadlines. It combines Firebase Authentication, Firestore task planning, mood check-ins, and simple stress insights so a student can turn academic pressure into a clear next step.

## Features

- Sign in with email and password using Firebase Auth.
- Register with email and password, then automatically send an email verification message.
- Sign in with Google using Firebase Auth.
- Store user profile data in Firestore: UID, email, name, avatar, and login timestamps.
- Store the main app data in Firestore, not local storage.
- Create, read, update, complete, and delete deadline tasks.
- Create and read mood check-ins connected to stress insights.
- Responsive Material 3 UI with a custom MindFlow palette: голубой, бежевый, зелёный, белый, and лавандовый.
- Custom Android launcher icon and app label.

## Firebase Setup

This repository does not include private Firebase project credentials. To make the APK authenticate against your Firebase project:

1. Create a Firebase project.
2. Add an Android app with package name `com.example.flutter_application_1`.
3. Run `dart pub global activate flutterfire_cli` if FlutterFire CLI is not installed.
4. Run `flutterfire configure` from this folder. This replaces the placeholder `lib/firebase_options.dart` with real Firebase project options.
5. Enable Firebase Auth providers: Email/Password and Google.
6. Create a Cloud Firestore database.
7. Optional for Google Sign-In ID token support: pass your web client ID at build/run time:

```sh
flutter run --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

Without Firebase configuration, the app opens a setup screen instead of crashing.

## Firestore Data Shape

```text
users/{uid}
  uid
  email
  name
  avatar
  createdAt
  lastLoginAt

users/{uid}/tasks/{taskId}
  title
  subject
  dueDate
  completed
  createdAt
  updatedAt

users/{uid}/moods/{moodId}
  mood
  stress
  note
  createdAt
```

## Run

```sh
flutter pub get
flutter run
```

## Build APK

```sh
flutter build apk --debug
```

For a store-ready release APK, configure proper Android signing first and then run:

```sh
flutter build apk --release
```
