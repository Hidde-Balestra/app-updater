# App Updater

Een Flutter-app om apps te installeren en te updaten buiten de Play Store om — via GitHub Releases, F-Droid of een directe `.apk`-URL. Vergelijkbaar met [Obtainium](https://github.com/ImranR98/Obtainium), maar dan met een eigen kleine set favoriete/curated apps ingebakken.

Ontworpen op basis van deze [Figma-schermen](https://www.figma.com/design/i81CFUd0QuoPNq6zyqraK6/AppUpdater---Flutter-App-Design).

## Functionaliteit

- **Mijn apps**: apps die je zelf hebt toegevoegd via een GitHub-repo, een F-Droid package-id, of een directe `.apk`-link.
- **Favoriete apps**: een meegeleverde lijst met suggesties die je met één tik kunt toevoegen — momenteel:
  - [TaalLeer](https://github.com/Hidde-Balestra/taalleer/releases)
  - [Task Planner](https://github.com/Hidde-Balestra/Task_Planner/releases)
  - [MusicPlayer](https://github.com/privacy-creator/musicplayer-flutter)
  - [F-Droid](https://f-droid.org/en/)
- Updates worden gedetecteerd via de GitHub Releases API (nieuwste `.apk`-asset) of de F-Droid index-API, en rechtstreeks gedownload en geïnstalleerd via de Android package installer.
- Instellingen: donkere modus, taal (Nederlands, Engels, Spaans, Duits, Italiaans), automatisch controleren op updates, alleen-wifi, meldingen.
- Geen Google Play Services, geen tracking, geen accounts.

### Nieuwe favoriete apps toevoegen

De meegeleverde suggesties staan in [`assets/curated_apps.json`](assets/curated_apps.json). Voeg daar een nieuw object toe met `id`, `name`, `sourceType` (`github`/`fdroid`/`direct`), `sourceIdentifier` en `infoUrl` om een nieuwe app aan de lijst toe te voegen — geen Dart-code nodig.

## Lokaal draaien

```bash
flutter pub get
flutter gen-l10n   # genereert lib/l10n/app_localizations*.dart uit de ARB-bestanden
flutter run
```

## Tests

```bash
flutter analyze
flutter test
```

## Releases & signing

De release-workflow ([`.github/workflows/release.yml`](.github/workflows/release.yml)) bouwt bij elke tag `v*` een ondertekende universele APK en publiceert die als GitHub Release. Daarvoor zijn 4 repo-secrets nodig:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

Zonder deze secrets faalt de workflow bewust (in plaats van stilletjes met een debug-sleutel te ondertekenen — een debug-signed APK kan een eerder geïnstalleerde versie niet updaten).

**Bewaar de `.jks`-keystore veilig en buiten git.** Als deze kwijtraakt, kunnen toekomstige releases bestaande installaties niet meer updaten (Android vereist dezelfde signing-sleutel voor updates); gebruikers zouden dan de app opnieuw moeten installeren.

Release notes worden altijd in het Engels gepubliceerd (GitHub's auto-generated release notes op basis van Engelstalige commit-/PR-titels), ongeacht de voertaal van de rest van de repo.

## Bekende beperkingen

- "Automatisch controleren" checkt bij het opstarten/hervatten van de app en via een timer zolang de app open is — er is (nog) geen echte OS-achtergrondtaak (bijv. via WorkManager). Een controle gebeurt dus pas zodra je de app weer opent, niet exact elke N uur terwijl de app gesloten is.
- Voor directe `.apk`-URL's is er geen versie-informatie beschikbaar; de app onthoudt alleen of je die bron al eens hebt geïnstalleerd.
