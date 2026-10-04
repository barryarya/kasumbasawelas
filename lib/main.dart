import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notification_service.dart';

import 'auth/setup_petugas_page.dart';
import 'pilih_toko_page.dart';
import 'auth/splash_screen.dart';
import 'core/price_config.dart';
import 'core/staff_access_config.dart';
import 'core/kulakan_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase background init error: $e");
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showPopup({required String title, required String body}) {
  final context = navigatorKey.currentContext;
  if (context == null) return;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

// Background initialization of Firebase & Notifications so app launch is NEVER blocked
Future<void> _initFirebaseAndNotifications() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await NotificationService.init(
      onNotificationTap: (payload) {
        if (payload == null) return;
        final data = payload.split("|");
        Future.delayed(const Duration(milliseconds: 300), () {
          showPopup(
            title: data.isNotEmpty ? data[0] : "Notifikasi",
            body: data.length > 1 ? data[1] : "",
          );
        });
      },
    );

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    try {
      String? token = await messaging.getToken().timeout(
        const Duration(seconds: 5),
      );
      debugPrint("FCM TOKEN: $token");
    } catch (e) {
      debugPrint("FCM getToken error: $e");
    }

    try {
      await FirebaseMessaging.instance
          .subscribeToTopic('pengingat')
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("FCM subscribeToTopic error: $e");
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      NotificationService.showNotification(
        title: message.notification?.title ?? "Kasumba",
        body: message.notification?.body ?? "",
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Future.delayed(const Duration(milliseconds: 300), () {
        showPopup(
          title: message.notification?.title ?? "Notifikasi",
          body: message.notification?.body ?? "",
        );
      });
    });

    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage()
        .timeout(const Duration(seconds: 3));
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        showPopup(
          title: initialMessage.notification?.title ?? "Notifikasi",
          body: initialMessage.notification?.body ?? "",
        );
      });
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initializeDateFormatting('id', null);
  } catch (e) {
    debugPrint("Date formatting init error: $e");
  }

  try {
    await PriceConfig.init();
  } catch (e) {
    debugPrint("PriceConfig init error: $e");
  }

  try {
    await StaffAccessConfig.init();
  } catch (e) {
    debugPrint("StaffAccessConfig init error: $e");
  }

  try {
    await KulakanService.init();
  } catch (e) {
    debugPrint("KulakanService init error: $e");
  }

  // 🚀 Start Flutter UI immediately so the user never gets stuck on a blank white screen
  runApp(const MyApp());

  // Initialize Firebase in background non-blocking
  _initFirebaseAndNotifications();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Catatan Penjualan Ubi',
      theme: ThemeData(primarySwatch: Colors.brown),
      home: const SplashScreen(),
    );
  }
}

class SplashCheck extends StatelessWidget {
  const SplashCheck({super.key});

  Future<bool> _isPetugasSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isSet = prefs.getBool('isPetugasSet') ?? false;

      debugPrint('isPetugasSet = $isSet');
      debugPrint('namaPetugas = ${prefs.getString('namaPetugas')}');
      debugPrint('rolePetugas = ${prefs.getString('rolePetugas')}');

      return isSet;
    } catch (e) {
      debugPrint("SharedPreferences error: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isPetugasSet(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F7F4),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8A00)),
            ),
          );
        }

        if (snapshot.data == true) {
          return const PilihTokoPage();
        }

        return const SetupPetugasPage();
      },
    );
  }
}
