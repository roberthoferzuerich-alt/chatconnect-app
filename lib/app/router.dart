import 'package:app/features/auth/domain/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_provider.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/chat/presentation/main_screen.dart';
import '../features/chat/presentation/user_search_screen.dart';
import '../features/chat/presentation/new_call_screen.dart';
import '../features/chat/presentation/create_group_screen.dart';
import '../features/chat/presentation/archived_chats_screen.dart';
import '../features/chat/presentation/contact_sync_screen.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/user_guide_screen.dart';
import '../features/settings/presentation/about_me_screen.dart';
import '../features/settings/presentation/story_settings_screen.dart';
import '../features/settings/presentation/privacy_settings_screen.dart';
import '../features/settings/presentation/blocked_contacts_screen.dart';
import '../features/settings/presentation/chats_settings_screen.dart';
import '../features/settings/presentation/notification_settings_screen.dart';
import '../features/settings/presentation/backup_settings_screen.dart';
import '../features/settings/presentation/storage_settings_screen.dart';
import '../features/story/presentation/create_story_screen.dart';
import '../features/story/presentation/story_viewer_screen.dart';
import '../features/story/presentation/my_stories_screen.dart';
import '../features/story/domain/story_model.dart';
import '../features/assistant/presentation/assistant_image_generator_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ValueNotifier<AsyncValue<User?>>(const AsyncValue.loading());

  ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
    notifier.value = next;
  });

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = notifier.value;
      final isAuth = authState.value != null;
      final isSplash = state.uri.path == '/splash';
      final isLogin = state.uri.path == '/login';
      final isRegister = state.uri.path == '/register';

      // Wenn die App noch lädt, bleib auf dem Splash-Screen (oder der aktuellen Seite)
      if (authState.isLoading) return null;

      // Wenn das Laden fertig ist und wir auf Splash sind, leite weiter
      if (isSplash) {
        return isAuth ? '/chats' : '/login';
      }

      // Wenn wir nicht eingeloggt sind und versuchen, geschützte Seiten aufzurufen
      if (!isAuth && !isLogin && !isRegister) {
        return '/login';
      }

      // Wenn wir eingeloggt sind und versuchen, Auth-Seiten aufzurufen
      if (isAuth && (isLogin || isRegister)) {
        return '/chats';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(path: '/chats', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/archived_chats',
        builder: (context, state) => const ArchivedChatsScreen(),
      ),
      GoRoute(
        path: '/user_guide',
        builder: (context, state) => const UserGuideScreen(),
      ),
      GoRoute(
        path: '/about_me',
        builder: (context, state) => const AboutMeScreen(),
      ),
      GoRoute(
        path: '/settings_chats',
        builder: (context, state) => const ChatsSettingsScreen(),
      ),
      GoRoute(
        path: '/settings_stories',
        builder: (context, state) => const StorySettingsScreen(),
      ),
      GoRoute(
        path: '/settings_privacy',
        builder: (context, state) => const PrivacySettingsScreen(),
      ),
      GoRoute(
        path: '/settings_privacy_blocked',
        builder: (context, state) => const BlockedContactsScreen(),
      ),
      GoRoute(
        path: '/settings_notifications',
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: '/settings_backups',
        builder: (context, state) => const BackupSettingsScreen(),
      ),
      GoRoute(
        path: '/settings_storage',
        builder: (context, state) => const StorageSettingsScreen(),
      ),
      GoRoute(
        path: '/sync_contacts',
        builder: (context, state) => const ContactSyncScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const UserSearchScreen(),
      ),
      GoRoute(
        path: '/new_call',
        builder: (context, state) => const NewCallScreen(),
      ),
      GoRoute(
        path: '/create_group',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/create_story',
        builder: (context, state) =>
            CreateStoryScreen(imagePath: state.extra as String),
      ),
      GoRoute(
        path: '/view_story',
        builder: (context, state) =>
            StoryViewerScreen(stories: state.extra as List<Story>),
      ),
      GoRoute(
        path: '/my_stories',
        builder: (context, state) =>
            MyStoriesScreen(storyGroup: state.extra as UserStoryGroup),
      ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) {
          final targetConvoId = state.extra is int ? state.extra as int : null;
          return AssistantImageGeneratorScreen(targetConversationId: targetConvoId);
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ChatScreen(conversationId: id);
        },
      ),
    ],
  );
});
