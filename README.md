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
- **Prawy sidebar z ulubionymi**: ta sama lista ulubionych po prawej stronie okna
  (bez dysków i zajętości) — szybka nawigacja **prawnego panelu**; lewy sidebar
  nawiguje lewy panel.
- **Stopka dysku**: na dole sidebaru pasek zajętości woluminu aktywnego panelu
  z liczbami GB i procentem („Zajęte 401,9 GB z 994,61 GB (40%)"); kolor przechodzi
  w pomarańcz/czerwony powyżej 75%/90% zapełnienia.
- **Dwa niezależne panele** z pełnym dostępem do systemu plików (bez sandboxa).
  Kliknięcie panelu lub zmiana zaznaczenia w nim aktywuje go (niebieska ramka,
  „Aktywny: Panel N"); operacje idą **z aktywnego panelu do drugiego**.
- **Natywna tabela plików (NSTableView)**: wielokrotne zaznaczanie cmd/shift,
  dwuklik otwiera, kliknięcie nagłówka sortuje (Nazwa/Rozmiar/Data),
  **kolumny o zmiennej szerokości** (przeciągnij granicę nagłówka; szerokości
  zapamiętywane) **dopasowujące się do szerokości panelu** (jak w Finderze —
  zwężanie panelu kurczy kolumny do minimów, Nazwa wypełnia resztę; poniżej
  sumy minimów działa przewijanie poziome: shift + kółko / trackpad poziomo),
  ikony plików jak w Finderze, katalogi najpierw, filtr bieżącego
  katalogu (⌘F), ukryte pliki (⌘⇧.).
- **Skróty w standardzie Total Commandera** (+ skróty macOS jak w Finderze):

  | Klawisz | Akcja |
  |---|---|
  | Enter | wejdź do folderu / otwórz plik pod kursorem |
  | Backspace lub Ctrl+PgUp | poziom wyżej |
  | Ctrl+PgDn | wejdź do folderu / otwórz plik |
  | Tab | przełącz aktywny panel |
  | Space / Insert | zaznacz/odznacz element pod kursorem i przejdź w dół |
  | Gray+ / Gray- | zaznacz / odznacz grupę wg wzorca (`*.txt`, alternatywy `|`) |
  | F2 | odśwież panele |
  | F3 / Ctrl+Q | podgląd Quick Look |
  | F4 | edytuj plik (TextEdit) |
  | F5 / F6 | kopiuj / przenieś do drugiego panelu |
  | Shift+F6 | zmień nazwę |
  | F7 | nowy folder |
  | F8 / Delete | usuń (dialog: Kosz lub trwale) |
  | Alt+F5 / Alt+F6 | spakuj do ZIP / rozpakuj archiwum |
  | Alt+Enter | właściwości pliku (Info) |
  | ⌘A | zaznacz wszystko |
  | ⌘C / ⌘X / ⌘V | kopiuj / wytnij / wklej pliki (działa też ze schowkiem Findera) |
  | ⌘⌥C | kopiuj ścieżki zaznaczonych elementów |
  | ⌘⌫ | przenieś do Kosza |
  | ⌘I | informacje o pliku |
  | ⌘⇧N | nowy folder |
  | ⌘O lub ⌘↓ | otwórz |
  | ⌘↑ | poziom wyżej |
  | ⌘1 / ⌘2 | aktywuj panel 1 / 2 |
  | ⌘F | filtr · ⌘R odśwież · ⌘⇧. ukryte pliki |

- **Pomoc w aplikacji**: menu Pomoc → „Skróty klawiszowe" (⌘? lub **F1**) —
  pełna, przewijalna lista powyższych skrótów.

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

Instalacja do /Applications (po buildzie Release):

```bash
xcodebuild -project FreeCommander.xcodeproj -scheme FreeCommander -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath build/DerivedData build
ditto build/DerivedData/Build/Products/Release/FreeCommander.app /Applications/FreeCommander.app
open /Applications/FreeCommander.app
```

Aplikacja podpisana ad-hoc lokalnie (bez konta dewelopera). `--fc-snapshot <ścieżka>`
to ukryty tryb weryfikacyjny: renderuje okno do PNG (CGWindowList, self-capture)
i kończy działanie.

## FreeCommander jako domyślna aplikacja do folderów

Aplikacja rejestruje się w Launch Services jako przeglądarka folderów
(`CFBundleDocumentTypes` → `public.folder` / `public.directory` w `project.yml`),
więc pojawia się w „Otwórz za pomocą" (menu kontekstowe / Get Info) dla folderów.
Otwarcie folderu z zewnątrz przenosi aktywny panel do tego folderu (`onOpenURL`).

Aby foldery otwierane przez inne aplikacje (np. „Pokaż pobrany plik" w przeglądarce)
trafiały do FreeCommandera: **Pliki → „Otwieraj foldery domyślnie w FreeCommanderze"**
(te samo pole cofa zmianę i przywraca Finder). Po tej zmianie okno Findera, biurko
i podwójny klik na folderze w Finderze nadal obsługuje Finder — system nie pozwala
zastąpić go jako powłoki; zmiana dotyczy aplikacji korzystających z domyślnego
handlera folderów (przeglądarki, dialogi). Gdyby system poprosił o potwierdzenie,
zatwierdź dialog. Alternatywa ręczna: Get Info na dowolnym folderze → „Otwórz za
pomocą": FreeCommander → „Zmień wszystko…".

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
                SidebarView (lewy: ulubione + dyski z paskami + stopka GB/%;
                prawy: tylko ulubione), FilePaneView,
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
