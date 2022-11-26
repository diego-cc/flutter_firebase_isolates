import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_isolates/firebase_options.dart';
import 'package:gap/gap.dart';
import 'package:isolate_handler/isolate_handler.dart';
import 'package:responsive_sizer/responsive_sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const collectionName = 'test_collection';
const docID = '1';
const listenForChangesInFirestoreKeyName = 'listenForChangesInFirestore';
const uuid = Uuid();
final isolates = IsolateHandler();

/// Receives `messages` in the following formats:
///
/// ```
/// {'collection': '<collection name>', 'doc': '<document ID>'}
/// {'terminate': true/false}
/// ```
///
/// And sends the contents of your document back to the main isolate.
@pragma('vm:entry-point')
void listenForChangesInFirestore(Map<String, dynamic> args) {
  final messenger = HandledIsolate.initialize(args);

  messenger.listen((message) async {
    assert(
      message is Map<String, dynamic>,
      'message MUST be a Map<String, dynamic>!',
    );

    debugPrint(
      '[listenForChangesInFirestore] Received a message: $message',
    );

    final parsedMessage = message as Map<String, dynamic>;

    if (parsedMessage.containsKey('collection') &&
        parsedMessage.containsKey('doc')) {
      final collection = parsedMessage['collection'] as String;
      final docID = parsedMessage['doc'] as String;

      try {
        await Firebase.initializeApp(
          name: 'flutter_firebase_demo_${uuid.v4()}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (err) {
        debugPrint('Could not initialise Firebase: $err');
      }

      try {
        final userCredentials = await FirebaseAuth.instance.signInAnonymously();
        debugPrint(
            'Signed in through FirebaseAuth as: ${userCredentials.user?.uid}');
      } catch (err) {
        debugPrint('Could not sign in anonymously through FirebaseAuth: $err');
      }

      /// The app WILL crash if you kill this isolate after calling:
      ///
      /// FirebaseFirestore.instance.collection(_).doc(_).snapshots().listen(...)
      ///
      /// instead of:
      ///
      /// FirebaseFirestore.instance.collection(_).doc(_).get()
      ///
      /// See: https://github.com/firebase/flutterfire/issues/6155

      /* final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(docID)
          .get();

      final data = doc.data();

      debugPrint(
        'Fetched a document with ID = $docID inside [listenForChangesInFirestore]: $data',
      );

      messenger.send(data); */

      FirebaseFirestore.instance
          .collection(collection)
          .doc(docID)
          .snapshots()
          .listen(
        (snapshot) {
          final data = snapshot.data();

          debugPrint(
            '[listenForChangesInFirestore] Received a doc snapshot: $data',
          );

          messenger.send(data);
        },
        onError: (err) {
          debugPrint(
            '[listenForChangesInFirestore] Got an error: $err',
          );
        },
        onDone: () {
          debugPrint(
            '[listenForChangesInFirestore]: onDone',
          );
        },
      );
    } else if (parsedMessage.containsKey('terminate')) {
      assert(
        parsedMessage['terminate'] is bool,
        'parsedMessage["terminate"] MUST be a boolean value!',
      );

      /// Terminating FirebaseFirestore has no effect here
      /* final terminate = parsedMessage['terminate'] as bool;

      if (terminate) {
        await FirebaseFirestore.instance.terminate();
        await FirebaseFirestore.instance.clearPersistence();
      } */
    }
  });
}

/// Launches a new isolate with [listenForChangesInFirestore] as the entry point.
Future<void> spawnFirestoreListener() async {
  final isolateName = 'listenForChangesInFirestore_${uuid.v4()}';
  final sharedPrefs = await SharedPreferences.getInstance();

  await sharedPrefs.setString(listenForChangesInFirestoreKeyName, isolateName);

  isolates.spawn<Map<String, dynamic>?>(
    listenForChangesInFirestore,
    name: isolateName,
    onReceive: (message) {
      debugPrint('Received a message from $isolateName: $message');
    },
    onInitialized: () {
      isolates.send(
        {
          'collection': collectionName,
          'doc': docID,
        },
        to: isolateName,
      );
    },
  );
}

/// Stops the execution of [listenForChangesInFirestore].
Future<void> killFirestoreListener() async {
  final sharedPrefs = await SharedPreferences.getInstance();

  final isolateName = sharedPrefs.getString(listenForChangesInFirestoreKeyName);

  if (isolateName != null) {
    try {
      isolates.send({'terminate': true}, to: isolateName);

      /// This delay is unnecessary; it's only been added to emphasise
      /// that the app crashes when you call isolates.kill(_)
      /// whilst having an open stream and the exception that is thrown
      /// cannot be caught on the Dart side.
      await Future.delayed(const Duration(seconds: 3), () {
        try {
          isolates.kill(isolateName);
          debugPrint('Terminated $isolateName!');
        } catch (err) {
          debugPrint('Could not terminate $isolateName: $err');
        }
      });
    } catch (err) {
      debugPrint('Could not terminate $isolateName: $err');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Since we aren't using Firebase in the main isolate,
  /// there's no need to initialise it here.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveSizer(
      builder: (ctx, orientation, screenType) => MaterialApp(
        title: 'Flutter Firebase Isolates Demo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const MyHomePage(title: 'Flutter Firebase Isolates Demo'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Future<void> startListeningForChangesToTestCollection() async {
    setState(() {
      isStartListeningButtonEnabled = false;
      isStopListeningButtonEnabled = false;
    });

    await spawnFirestoreListener();

    setState(() {
      isStartListeningButtonEnabled = false;
      isStopListeningButtonEnabled = true;
    });
  }

  Future<void> stopListeningForChangesToTestCollection() async {
    setState(() {
      isStartListeningButtonEnabled = false;
      isStopListeningButtonEnabled = false;
    });

    await killFirestoreListener();

    setState(() {
      isStartListeningButtonEnabled = true;
      isStopListeningButtonEnabled = false;
    });
  }

  bool isStartListeningButtonEnabled = true;
  bool isStopListeningButtonEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 64,
              ),
              child: Text(
                'Tap the button below to start listening for changes to a document with ID = 1 in test_collection from a separate isolate.',
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                      fontSize: 18,
                      height: 1.5,
                    ),
              ),
            ),
            Gap(4.h),
            ElevatedButton(
              onPressed: isStartListeningButtonEnabled
                  ? () async => await startListeningForChangesToTestCollection()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                disabledBackgroundColor: Colors.grey,
              ),
              child: Text(
                'Start Listening',
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                      fontSize: 18,
                      color: Colors.white,
                    ),
              ),
            ),
            Gap(2.h),
            ElevatedButton(
              onPressed: isStopListeningButtonEnabled
                  ? () async => await stopListeningForChangesToTestCollection()
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                disabledBackgroundColor: Colors.grey,
              ),
              child: Text(
                'Stop Listening',
                style: Theme.of(context).textTheme.bodyText1?.copyWith(
                      fontSize: 18,
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
