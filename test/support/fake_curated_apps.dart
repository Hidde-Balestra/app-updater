import 'package:app_updater/models/app_source_type.dart';
import 'package:app_updater/models/curated_app.dart';

/// Mirrors assets/curated_apps.json for widget tests. Passed via
/// AppLibrary.load(curatedAppsOverride: ...) so widget tests never call
/// rootBundle.loadString — see the doc comment on AppLibrary.load for why.
const testCuratedApps = [
  CuratedApp(
    id: 'taalleer',
    name: 'TaalLeer',
    sourceType: AppSourceType.github,
    sourceIdentifier: 'Hidde-Balestra/taalleer',
    infoUrl: 'https://github.com/Hidde-Balestra/taalleer/releases',
  ),
  CuratedApp(
    id: 'task_planner',
    name: 'Task Planner',
    sourceType: AppSourceType.github,
    sourceIdentifier: 'Hidde-Balestra/Task_Planner',
    infoUrl: 'https://github.com/Hidde-Balestra/Task_Planner/releases',
  ),
  CuratedApp(
    id: 'musicplayer',
    name: 'MusicPlayer',
    sourceType: AppSourceType.github,
    sourceIdentifier: 'privacy-creator/musicplayer-flutter',
    infoUrl: 'https://github.com/privacy-creator/musicplayer-flutter',
  ),
  CuratedApp(
    id: 'fdroid',
    name: 'F-Droid',
    sourceType: AppSourceType.direct,
    sourceIdentifier: 'https://f-droid.org/F-Droid.apk',
    infoUrl: 'https://f-droid.org/en/',
  ),
];
