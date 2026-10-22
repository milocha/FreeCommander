# FreeCommander (macOS)

Darmowy, dwupanelowy menedżer plików na macOS w duchu **Total Commandera** z nowoczesnym
interfejsem (sidebar w stylu ForkLift/Commander One, interakcje jak w Finderze):
dwa panele obok siebie, ulubione foldery, paski zajętości dysków, ZIP, Quick Look, Kosz.
Aplikacja **nie jest sandboxowana**, więc widzi cały dysk.

![FreeCommander na macOS](docs/screenshot-macos.png)

## Funkcje (v0.2)

- **Sidebar** (lewy panel): ulubione systemowe i **własne ulubione foldery** (gwiazdka
  w belce ścieżki dodaje bieżący folder), sekcja dysków z **paskiem zajętości** —
  „401,9 GB zajęte · 40%" dla każdego woluminu.
- **Stopka dysku**: na dole sidebaru pasek zajętości woluminu aktywnego panelu
  z liczbami GB i procentem („Zajęte 401,9 GB z 994,61 GB (40%)"); kolor przechodzi
  w pomarańcz/czerwony powyżej 75%/90% zapełnienia.
- **Dwa niezależne panele** z pełnym dostępem do systemu plików (bez sandboxa).
  Kliknięcie panelu lub zmiana zaznaczenia w nim aktywuje go (niebieska ramka,
  „Aktywny: Panel N"); operacje idą **z aktywnego panelu do drugiego**.
- **Natywna tabela plików (NSTableView)**: wielokrotne zaznaczanie cmd/shift,
  dwuklik otwiera, kliknięcie nagłówka sortuje (Nazwa/Rozmiar/Data),
  **kolumny o zmiennej szerokości** (przeciągnij granicę nagłówka; szerokości
  zapamiętywane), ikony plików jak w Finderze, katalogi najpierw, filtr bieżącego
  katalogu (⌘F), ukryte pliki (⌘⇧.).
- **Skróty w standardzie macOS** (jak Finder) **+ klasyczne F-klawisze Total Commandera**:

  | Klawisz | Akcja |
  |---|---|
  | ⌘C / ⌘X / ⌘V | kopiuj / wytnij / wklej pliki (działa też ze schowkiem Findera) |
  | ⌘⌫ | przenieś do Kosza |
  | ⌘I | informacje o pliku |
  | ⌘⇧N | nowy folder |
  | ⌘O lub ⌘↓ | otwórz |
  | ⌘↑ | poziom wyżej |
  | ⌘1 / ⌘2 | aktywuj panel 1 / 2 |
  | ⌘F | filtr · ⌘R odśwież · ⌘⇧. ukryte pliki · ⌘A zaznacz wszystko |
  | Space | podgląd Quick Look |
  | F5 / F6 | kopiuj / przenieś do drugiego panelu |
  | F7 / F8 / F2 | nowy folder / usuń (dialog) / zmień nazwę |
  | Tab | przełącz aktywny panel · Enter otwórz · Backspace poziom wyżej |

- **Operacje wsadowe z postępem**, konflikty nazw rozwiązywane automatycznie
  („nazwa (2).ext"), blokada przenoszenia folderu do własnego podfolderu.
- **ZIP** (ZIPFoundation) i rozpakowywanie; **Kosz** domyślnie (⌘⌫), usuwanie trwałe
  z menu kontekstowego / dialogu F8.
- **Belka ścieżki**: edytowalna ścieżka (Return = przejdź, `~` działa), menu dysków
  i woluminów, gwiazdka ulubionych.
- Menu kontekstowe: otwórz, podgląd, Pokaż w Finderze, kopiuj/przenieś do drugiego
  panelu, zmień nazwę, duplikuj, informacje, ZIP, rozpakuj, Kosz, usuń trwale.
- Stan paneli, sortowanie, szerokości kolumn i ulubione zapamiętywane między
  uruchomieniami. Języki: **PL + EN**. Własna ikona aplikacji.

## Budowanie i uruchamianie

Wymagany Xcode (projekt generowany z [xcodegen](https://github.com/yonaskolb/XcodeGen)):

```bash
brew install xcodegen
xcodegen generate                      # tworzy FreeCommander.xcodeproj z project.yml
open FreeCommander.xcodeproj           # w Xcode: ⌘R
```

Build i testy z CLI:

```bash
xcodebuild -project FreeCommander.xcodeproj -scheme FreeCommander \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData build

xcodebuild -project FreeCommander.xcodeproj -scheme FreeCommander \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData test
```

Uruchomienie zbudowanej aplikacji:

```bash
open build/DerivedData/Build/Products/Debug/FreeCommander.app
```

Aplikacja podpisana ad-hoc lokalnie (bez konta dewelopera). `--fc-snapshot <ścieżka>`
to ukryty tryb weryfikacyjny: renderuje okno do PNG (CGWindowList, self-capture)
i kończy działanie.

## Architektura

```
FreeCommander/
  App/          FreeCommanderApp (punkt wejścia, tryb snapshotu, menu Commands)
  Models/       FileItem, SortField/Direction, FavoriteLocation/SystemLocations, VolumeUsage
  Services/     FileSystemService (lista/operacje/ZIP/Kosz), FileClipboard (⌘C/⌘X/⌘V),
                FavoritesStore (własne ulubione), SettingsStore, OperationsEngine
  ViewModels/   PaneViewModel — stan panelu: katalog, zawartość, zaznaczenie, sort,
                filtr, zajętość woluminu, żądania dialogów
  Views/        ContentView (NavigationSplitView + 2 panele + router komend),
                SidebarView (ulubione + dyski z paskami + stopka GB/%), FilePaneView,
                FileListView (NSTableView: zaznaczanie, dwuklik, sort nagłówkami,
                zmienne kolumny, menu kontekstowe), BottomActionBar, InfoSheet,
                QuickLookView, CommandRouter + KeyboardMonitor (skróty macOS + TC)
  Resources/    Assets.xcassets (ikona), pl.lproj / en.lproj
Tests/          19 testów jednostkowych rdzenia (listy, sort, operacje, ZIP, ulubione, dyski)
```

Zależność zewnętrzna: [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (MIT).

## Mapa drogowa

- [ ] Widok drzewa katalogów, zakładki z sortowaniem własnym
- [ ] Porównywanie paneli (sync katalogów jak w TC), wybór trybu konfliktów (nadpisz/pomiń)
- [ ] Edytor tekstu (F4), wiersz poleceń
- [ ] Archiwa 7z/RAR (odczyt), tar.gz
- [ ] Drag & drop między panelami i z Findera, podświetlanie wyciętych plików
- [ ] Rozmiary pakietów .app (teraz „zero KB"), konfigurowalne kolumny (widoczność)
- [ ] Motyw jasny/ciemny w stylu TC

## Wersja iOS

Pierwotny prototyp na iOS/iPadOS jest zachowany na gałęzi `ios-mvp` tego repozytorium.
