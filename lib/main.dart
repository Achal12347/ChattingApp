import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_routes.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'providers/settings_provider.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/chat_screen.dart';
import 'screens/home/create_group_screen.dart';
import 'screens/home/group_chat_screen.dart';
import 'screens/home/group_settings_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/join_group_screen.dart';
import 'screens/home/mood_tracking_screen.dart';
import 'screens/home/qr_code_screen.dart';
import 'screens/home/qr_scanner_screen.dart';
import 'screens/home/unblock_requests_screen.dart';
import 'screens/onboarding/welcome_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/privacy_settings_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash_screen.dart';
import 'services/app_lifecycle_service.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
RemoteMessage? _initialRemoteMessage;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _navigateFromRemoteMessage(RemoteMessage message) {
  final data = message.data;
  final type = data['type']?.toString();
  final chatId = data['chatId']?.toString();
  final groupId = data['groupId']?.toString();
  final senderId = data['senderId']?.toString() ?? '';
  final currentUser = FirebaseAuth.instance.currentUser;
  final currentUserId = currentUser?.uid ?? '';
  final navigator = appNavigatorKey.currentState;
  if (navigator == null || currentUser == null) return;

  if (type == 'group' && groupId != null && groupId.isNotEmpty) {
    navigator.pushNamed(
      AppRoutes.groupChat,
      arguments: {'groupId': groupId, 'currentUserId': currentUserId},
    );
    return;
  }

  if ((type == 'chat' || chatId != null) &&
      chatId != null &&
      chatId.isNotEmpty &&
      senderId.isNotEmpty) {
    navigator.pushNamed(
      AppRoutes.chat,
      arguments: {
        'chatId': chatId,
        'receiverId': senderId,
        'currentUserId': currentUserId,
      },
    );
  }
}

void _navigateFromPayload(NotificationPayload payload) {
  final navigator = appNavigatorKey.currentState;
  final currentUser = FirebaseAuth.instance.currentUser;
  if (navigator == null || currentUser == null) return;

  if (payload.type == 'group' && (payload.groupId?.isNotEmpty ?? false)) {
    navigator.pushNamed(
      AppRoutes.groupChat,
      arguments: {
        'groupId': payload.groupId,
        'currentUserId': currentUser.uid,
      },
    );
    return;
  }

  if (payload.type == 'chat' &&
      (payload.chatId?.isNotEmpty ?? false) &&
      (payload.senderId?.isNotEmpty ?? false)) {
    navigator.pushNamed(
      AppRoutes.chat,
      arguments: {
        'chatId': payload.chatId,
        'receiverId': payload.senderId,
        'currentUserId': currentUser.uid,
      },
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  final notificationService = NotificationService();
  await notificationService.initialize();

  FirebaseMessaging.onMessageOpenedApp.listen(_navigateFromRemoteMessage);
  _initialRemoteMessage = await messaging.getInitialMessage();

  notificationService.onNotificationTapped.listen(_navigateFromPayload);

  final fcmToken = await notificationService.getFCMToken();
  if (fcmToken != null && FirebaseAuth.instance.currentUser != null) {
    await AuthService()
        .updateFcmToken(FirebaseAuth.instance.currentUser!.uid, fcmToken);
  }

  runApp(const ProviderScope(child: ChatlyApp()));
}

class ChatlyApp extends ConsumerStatefulWidget {
  const ChatlyApp({super.key});

  @override
  ConsumerState<ChatlyApp> createState() => _ChatlyAppState();
}

class _ChatlyAppState extends ConsumerState<ChatlyApp> {
  @override
  void initState() {
    super.initState();
    ref.read(appLifecycleServiceProvider).init();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initial = _initialRemoteMessage;
      if (initial != null) {
        _navigateFromRemoteMessage(initial);
        _initialRemoteMessage = null;
      }
    });
  }

  @override
  void dispose() {
    ref.read(appLifecycleServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final selectedThemeMode = resolveThemeMode(settings.themeMode);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Chatly',
      debugShowCheckedModeBanner: false,
      theme: getLightTheme(settings.themePreset),
      darkTheme: getDarkTheme(settings.themePreset),
      themeMode: selectedThemeMode,
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash: (_) => const SplashScreen(),
        AppRoutes.welcome: (_) => const WelcomeScreen(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.signup: (_) => const SignupScreen(),
        AppRoutes.forgotPassword: (_) => const ForgotPasswordScreen(),
        AppRoutes.home: (_) => const HomeScreen(),
        AppRoutes.chat: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return ChatScreen(
            chatId: args?['chatId']?.toString() ?? '',
            receiverId: args?['receiverId']?.toString() ?? '',
            currentUserId: args?['currentUserId']?.toString() ?? '',
          );
        },
        AppRoutes.groupChat: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return GroupChatScreen(
            groupId: args?['groupId']?.toString() ?? '',
            currentUserId: args?['currentUserId']?.toString() ?? '',
          );
        },
        AppRoutes.createGroup: (_) => const CreateGroupScreen(),
        AppRoutes.joinGroup: (_) => const JoinGroupScreen(),
        AppRoutes.groupSettings: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return GroupSettingsScreen(
              groupId: args?['groupId']?.toString() ?? '');
        },
        AppRoutes.groupProfile: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return GroupSettingsScreen(
            groupId: args?['groupId']?.toString() ?? '',
            isProfileMode: true,
          );
        },
        AppRoutes.moodTracking: (_) => const MoodTrackingScreen(),
        AppRoutes.qrCode: (_) => const QRCodeScreen(),
        AppRoutes.qrScanner: (_) => const QRScannerScreen(),
        AppRoutes.profile: (context) {
          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          return ProfileScreen(userId: args?['userId']?.toString());
        },
        AppRoutes.editProfile: (_) => const EditProfileScreen(),
        AppRoutes.settings: (_) => const SettingsScreen(),
        AppRoutes.privacySettings: (_) => const PrivacySettingsScreen(),
        AppRoutes.unblockRequests: (_) => const UnblockRequestsScreen(),
      },
    );
  }
}
