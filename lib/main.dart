import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Handle background messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local Notification setup for displaying notifications when the app is in the foreground
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(MessagingApp());
}

class MessagingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Messaging Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MessagingHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MessagingHomePage extends StatefulWidget {
  @override
  _MessagingHomePageState createState() => _MessagingHomePageState();
}

class _MessagingHomePageState extends State<MessagingHomePage> {
  String? _token;
  List<String> _notificationHistory = [];

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission on iOS and web for notifications
    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print("Permission granted!");
    } else {
      print("Permission denied!");
    }

    // Get the FCM token
    String? token = await messaging.getToken();
    setState(() {
      _token = token;
    });
    print("FCM Token: $_token");

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message received: ${message.notification?.body}');
      _handleMessage(message);
    });

    // Handle message opened when app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification clicked!');
    });
  }

  Future<void> _handleMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final type = data['type'] ?? 'regular';

    String title = notification?.title ?? "Notification";
    String body = notification?.body ?? "";

    // Save to notification history
    setState(() {
      _notificationHistory.add("[$type] $body");
    });

    // Local Notification for displaying notifications in the app
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Channel',
      channelDescription: 'Used for general notifications',
      importance: type == 'important' ? Importance.max : Importance.defaultImportance,
      priority: type == 'important' ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: type == 'important',
      sound: RawResourceAndroidNotificationSound(
          type == 'important' ? 'alert' : 'default'),
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );

    // Show dialog as well
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("FCM Messaging"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SelectableText("Your FCM Token:\n$_token"),
            const SizedBox(height: 20),
            Text(
              "Notification History:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _notificationHistory.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(_notificationHistory[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}