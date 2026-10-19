import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/battle/battle_screen.dart';
import '../features/campaign/campaign_shell.dart';
import '../features/country_selection/country_selection_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/diplomacy/diplomacy_screen.dart';
import '../features/economy/economy_screen.dart';
import '../features/events/events_screen.dart';
import '../features/industry/industry_screen.dart';
import '../features/main_menu/about_screen.dart';
import '../features/main_menu/main_menu_screen.dart';
import '../features/main_menu/settings_screen.dart';
import '../features/military/military_screen.dart';
import '../features/nations/nations_screen.dart';
import '../features/save/save_screen.dart';
import '../features/world_map/world_map_screen.dart';

/// Application routes.
class Routes {
  Routes._();

  static const String menu = '/';
  static const String about = '/about';
  static const String settings = '/settings';
  static const String newCampaign = '/new';

  static const String campaign = '/campaign';
  static const String map = '/campaign/map';
  static const String economy = '/campaign/economy';
  static const String military = '/campaign/military';
  static const String battle = '/campaign/battle';
  static const String diplomacy = '/campaign/diplomacy';
  static const String events = '/campaign/events';
  static const String save = '/campaign/save';
  static const String nations = '/campaign/nations';
  static const String industry = '/campaign/industry';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.menu,
    routes: [
      GoRoute(
        path: Routes.menu,
        builder: (context, state) => const MainMenuScreen(),
      ),
      GoRoute(
        path: Routes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.newCampaign,
        builder: (context, state) => const CountrySelectionScreen(),
      ),
      // Every campaign screen shares one persistent shell: the command bar,
      // the clock controls and the bottom navigation.
      ShellRoute(
        builder: (context, state, child) => CampaignShell(child: child),
        routes: [
          GoRoute(
            path: Routes.campaign,
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: Routes.map,
            builder: (context, state) => const WorldMapScreen(),
          ),
          GoRoute(
            path: Routes.economy,
            builder: (context, state) => const EconomyScreen(),
          ),
          GoRoute(
            path: Routes.military,
            builder: (context, state) => const MilitaryScreen(),
          ),
          GoRoute(
            path: Routes.battle,
            builder: (context, state) => const BattleScreen(),
          ),
          GoRoute(
            path: Routes.diplomacy,
            builder: (context, state) => const DiplomacyScreen(),
          ),
          GoRoute(
            path: Routes.events,
            builder: (context, state) => const EventsScreen(),
          ),
          GoRoute(
            path: Routes.save,
            builder: (context, state) => const SaveScreen(),
          ),
          GoRoute(
            path: Routes.nations,
            builder: (context, state) => const NationsScreen(),
          ),
          GoRoute(
            path: Routes.industry,
            builder: (context, state) => const IndustryScreen(),
          ),
        ],
      ),
    ],
  );
});
