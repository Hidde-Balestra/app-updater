# App Updater

Een Flutter-app om apps te installeren en te updaten buiten de Play Store om — via GitHub Releases, GitLab Releases, Codeberg Releases, F-Droid of een directe `.apk`-URL. Vergelijkbaar met [Obtainium](https://github.com/ImranR98/Obtainium), maar dan met een eigen kleine set favoriete/curated apps ingebakken.

Ontworpen op basis van deze [Figma-schermen](https://www.figma.com/design/i81CFUd0QuoPNq6zyqraK6/AppUpdater---Flutter-App-Design).

## Functionaliteit

- **Mijn apps**: apps die je zelf hebt toegevoegd via een GitHub-repo, GitLab-repo, Codeberg-repo, een F-Droid package-id, of een directe `.apk`-link — of via het tabblad "Van toestel" bij het toevoegen, dat alle apps toont die al op je telefoon staan maar nog niet getrackt worden, zodat je naam en package-naam niet met de hand hoeft over te typen.
- **Instellingen → Apparaat-apps**: centraal overzicht van alles wat op je toestel staat — getrackt, genegeerd of nog beschikbaar om toe te voegen. Apps die je niet wilt tracken kun je negeren zodat ze niet steeds terugkomen in de suggesties; genegeerde apps kun je op elk moment weer terugzetten.
- **Favoriete apps**: een meegeleverde lijst met suggesties die je met één tik kunt toevoegen — momenteel:
  - [TaalLeer](https://github.com/Hidde-Balestra/taalleer/releases)
  - [Task Planner](https://github.com/Hidde-Balestra/Task_Planner/releases)
  - [MusicPlayer](https://github.com/privacy-creator/musicplayer-flutter)
  - [F-Droid](https://f-droid.org/en/)
  - [Aurora Store](https://gitlab.com/AuroraOSS/AuroraStore) — anonieme Play Store-client zonder Google-account of Play Services; via Aurora Store zelf kun je daarna ook gewone Play Store-apps installeren en updaten.
- Updates worden gedetecteerd via de GitHub Releases API, de GitLab Releases API (nieuwste `.apk`-asset — inclusief projecten die de APK als link in de release-notes plakken in plaats van als losse asset, zoals Aurora Store doet), de Codeberg (Gitea/Forgejo) Releases API, of de F-Droid index-API, en rechtstreeks gedownload en geïnstalleerd via de Android package installer.
- **Alles updaten**: staat er meer dan één update klaar, dan verschijnt er een banner boven de lijst waarmee je in één tik alle apps met een beschikbare update achter elkaar download en installeert.
- **SHA-256-checksum**: na elke download wordt de SHA-256 van de gedownloade APK getoond (met kopieerknop), zodat je 'm zelf tegen een elders gepubliceerde hash kan controleren vóór het installeren.
- **Apparaat scannen**: voor een getrackte app kun je optioneel een Android package-naam invullen; de scan-knop leest dan via de package manager van het toestel de daadwerkelijk geïnstalleerde versie uit (in plaats van dat je die na een download-en-installeer handmatig hoeft te bevestigen) en controleert meteen opnieuw op updates. Na een download-en-installeer via de app zelf wordt het package name bovendien automatisch gedetecteerd (door het toestel vlak vóór en ná de installatie te vergelijken), dus meestal hoef je 'm niet met de hand in te vullen.
- **Back-up**: je apps-lijst kan als JSON naar het klembord geëxporteerd worden (en van daaruit weer geïmporteerd, bijv. op een nieuw toestel) via Instellingen.
- **Achtergrondcontrole**: als "Automatisch controleren" aanstaat, draait er een periodieke WorkManager-taak (minimaal elke 15 minuten, Android's eigen ondergrens) die ook checkt terwijl de app dicht is, en een melding toont zodra er updates beschikbaar zijn.
- Instellingen: donkere modus, taal (Nederlands, Engels, Spaans, Duits, Italiaans), automatisch controleren op updates, alleen-wifi, meldingen.
- Geen Google Play Services, geen tracking, geen accounts.

### Nieuwe favoriete apps toevoegen

De meegeleverde suggesties staan in [`assets/curated_apps.json`](assets/curated_apps.json). Voeg daar een nieuw object toe met `id`, `name`, `sourceType` (`github`/`gitlab`/`codeberg`/`fdroid`/`direct`), `sourceIdentifier` en `infoUrl` om een nieuwe app aan de lijst toe te voegen — geen Dart-code nodig.

### App-icoon aanpassen

Het launcher-icoon staat als bron in [`assets/icon/app_icon.svg`](assets/icon/app_icon.svg). Na het aanpassen van dat bestand genereer je de Android-mipmaps opnieuw met:

```bash
tool/render_app_icon.sh   # vereist rsvg-convert (librsvg2-bin)
```

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

- Android's WorkManager staat geen periodieke taken toe die vaker dan elke 15 minuten draaien; een korter ingestelde interval wordt automatisch naar 15 minuten afgerond. Fabrikant-specifieke batterij-optimalisatie kan de achtergrondtaak bovendien alsnog uitstellen — dit is niet iets wat de app zelf kan garanderen.
- Voor directe `.apk`-URL's is er geen versie-informatie beschikbaar; de app onthoudt alleen of je die bron al eens hebt geïnstalleerd.
- SHA-256-verificatie is informatief, geen automatische blokkade: GitHub's Releases API en de F-Droid-index publiceren geen betrouwbare checksum om automatisch tegen te controleren, dus de app toont 'm alleen zodat je 'm zelf kan vergelijken.
- Automatische package-name-detectie na installeren is best-effort: de app vergelijkt welke package er na de installatie is bijgekomen, maar kan dit niet garanderen als er op hetzelfde moment nog een andere app wordt geïnstalleerd.
- Er is bewust géén rechtstreekse Play Store-integratie (à la Aurora Store): dat vereist het namaken van Google's interne, ongedocumenteerde Play Store-protocol met anonieme tokens van een third-party tokendienst — fragiel, kan breken zodra Google iets wijzigt, en in strijd met Play Store's gebruiksvoorwaarden. In plaats daarvan staat Aurora Store zelf als favoriete app in de lijst; via GitLab Releases-ondersteuning (zie hierboven) kan de app 'm ook automatisch up-to-date houden.
- APK-mirrorsites als APKMirror, APKPure en Uptodown worden om dezelfde reden niet ondersteund: die zitten volledig achter een Cloudflare-JS-challenge (geverifieerd — zelfs hun `robots.txt` vereist het) en hebben geen publieke API. GitHub/GitLab/Codeberg-hosted releases zijn de aanpak die wél zonder browser-simulatie werkt.
