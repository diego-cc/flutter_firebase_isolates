# Flutter Firebase Isolates (Demo)

This is a small example meant to demonstrate how to read data from Firestore inside a separate isolate, as well as managing communication between isolates upon successful operations.

It also provides a reproducible scenario for [this issue](https://github.com/firebase/flutterfire/issues/6155 "[cloud_firestore] [__NSCFString setStreamHandler:]: unrecognized selector sent to instance 0x280d27d40 -[FLTFirebaseFirestorePlugin cleanupWithCompletion:]").

Please see the comments in `lib/main.dart` for context.

## Setting up

1. Open the project in your IDE or text editor of choice and replace all occurrences of `au.com.diegocc.flutterfirebaseisolates` with your own bundle identifier or application ID. 
2. Run `flutter clean && flutter pub get`.
3. __iOS:__ Run `cd ios/ && pod install --repo-update`.
4. __iOS:__ Open Xcode, navigate to Signing & Capabilities and ensure your provisioning profile and signing certificate have been set.
5. Create a new project in Firebase.
6. Enable anonymous authentication.
7. Create a collection in Firestore called __test_collection__ and add a document with __ID = 1__ containing any key-value pairs. Optionally, navigate to the _Rules_ tab and replace everything after `allow read, write:` with `if request.auth != null;`
8. Use the [`flutterfire`](https://firebase.google.com/docs/flutter/setup?platform=ios "Setting up Firebase") CLI to set up your Firebase installation, choosing the project you've just created and overriding the existing `firebase_options.dart` (if required).
9. Make sure you've got your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) added to `android/app/` or `ios/`, respectively.
10. __iOS:__ Build and run the app via Xcode for the first time and allow it to sign your app and perform any further operations required. You may then stop the debugging session once your app is up and running.
11. Run `flutter run`.

## Conclusions

- You must always call `Firebase.initializeApp(_)` inside your isolates, even if you've already initialised it in your main isolate.
- Using streams to listen for changes to documents in Firestore from separate isolates doesn't quite work due to the issue mentioned above. Your app crashes once you dispose them.
- Alternatively, you could start a timer in your main isolate to periodically perform one-off fetch operations by calling `FirebaseFirestore.instance.collection(_).doc(_).get()`. However, this is obviously less efficient and potentially way more expensive and dangerous to be used in production depending on your user base.
- There's a way to stop your app from crashing when using streams by applying [this simple workaround](https://github.com/firebase/flutterfire/issues/6155#issuecomment-846528546). Alas, it doesn't really address the root cause of this issue.
