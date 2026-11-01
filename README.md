# Fabryka Sort – prototyp

Gra logiczna w motywie automatyzacji produkcji. Robot-suwnica przenosi paczki z produktami między paletami. Cel: na każdej palecie ma zostać tylko jeden rodzaj produktu.

Nazwa jest robocza. Przed publikacją sprawdź, czy nie jest zajęta w Google Play i nie narusza cudzego znaku towarowego.

**Status:** prototyp do testów grywalności. To nie jest gotowy produkt. Sklep i reklamy działają tylko w **trybie testowym** (bez prawdziwych płatności i reklam).

## Szybki test w przeglądarce
`FabrykaSort.html` – cała gra w jednym pliku: otwórz dwuklikiem w Chrome/Edge. Budowa: `tools/build_single_html.py` (instrukcja w `docs/01_INSTALACJA_NA_TELEFONIE.md`).

## Dokumenty
- `docs/01_INSTALACJA_NA_TELEFONIE.md` – jak zbudować APK i zainstalować grę na telefonie
- `docs/02_PUBLIKACJA_GOOGLE_PLAY.md` – jak tanio opublikować grę w Google Play
- `docs/03_PLAN_WDROZENIA.md` – etapy od testów do premiery, kryteria decyzji, ryzyka
- `docs/04_KAMPANIA_MARKETINGOWA.md` – pozycjonowanie, teksty do sklepu, kanały, kalendarz
- `docs/06_HIERARCHIA_UTRUDNIEN.md` – pomiar wpływu utrudnień i ich kolejność (`tools/analyze_modifiers.gd`)
- `docs/05_ANKIETA_I_ANALIZA.md` – ankieta w grze, arkusz Google z automatyczną analizą (`docs/ankieta/Code.gs`)

## Wymagania
- **Godot 4.7.x, wersja standardowa** (nie .NET), z https://godotengine.org/download. Projekt sprawdzono na 4.7.2.
- Nic więcej do samej gry. Do ponownego wygenerowania dźwięków: Python 3 + numpy (opcjonalnie).

## Uruchomienie
1. Godot → **Import** → wskaż `project.godot` → **Import & Edit**.
2. **F5** (albo ▶). Okno ma proporcje telefonu.
3. Kliknij paletę, z której robot ma wziąć paczki (podświetli się na niebiesko), a potem paletę docelową.

## Tryby gry
Po uruchomieniu pojawia się **menu główne**:
- **Kampania** – zlecenia, gracz steruje robotem ruch po ruchu.
- **Programowanie robota** – osobny tryb. Gracz układa program (listę kroków „paleta » paleta”), a dopiero potem naciska **START**. W trakcie programowania plansza się nie zmienia, więc skutki kroków trzeba przewidzieć. Błędny krok zatrzymuje robota komunikatem „BŁĄD PROGRAMU” i wskazuje przyczynę; „Edytuj” wraca do edycji. Palety mieszczą po 3 paczki, a każdy program ma znane najkrótsze rozwiązanie i limit kroków.
- **Rozbudowa hali** – ozdoby kupowane za gwiazdki: kolor robota, ściana, posadzka, oświetlenie, zegar lub tablica wyników, zieleń, ramię robota w tle. Ozdoby zmieniają tylko wygląd i nie są sprzedawane za pieniądze.

## Gwiazdki
- **Kampania:** 3 gwiazdki za wynik nie gorszy niż wzorzec ruchów (pokazywany po wygranej), 2 za wynik blisko wzorca, 1 za resztę. Zmiana chwytaka liczy się jako ruch.
- **Programy:** 3 gwiazdki za najkrótszy program, 2 za o jeden krok dłuższy, 1 za resztę.
- Poprawienie wyniku dodaje brakujące gwiazdki.

## Punkty i rangi
- Za każde zlecenie i program: **baza (trudność poziomu) × gwiazdki (1★ 50%, 2★ 75%, 3★ 100%) × 1,2 bez podpowiedzi**. Liczy się najlepszy wynik każdego poziomu – powtarzanie nie nabija punktów.
- Rangi: Praktykant → Operator (500) → Technik automatyk (1500) → Programista robotów (3500) → Integrator (7000) → Inżynier automatyki (12000) → Główny automatyk (20000). Przy typowej grze awanse wypadają ok. przy zleceniach 10, 23, 46, 86, 143; najwyższa ranga wymaga 3 gwiazdek i programów.
- Menu → **Ranking**: ranga, pasek postępu, lista rang, statystyki. Wzory i progi: `scripts/score.gd`.

## Tryb programowania – krzywa trudności
| Programy | Produkty | Puste palety | Najkrótszy program |
|---|---|---|---|
| 1–3 (samouczek) | 2 | 2 | 2–4 kroki |
| 4–10 | 3 | 2 | 3–6 |
| 11–20 | 3→4 | 2 | 5–8 |
| 21–35 | 4 | 2→1 | 7–10 |
| 36–60 | 5 | 2→1 | 8–12 |
Co 5. program jest łatwiejszy. **Podgląd** pokazuje palety po wykonaniu obecnych kroków: za darmo w programach 1–3, potem za 1 podpowiedź.

## Wybór poziomu (tylko do testów)
Przycisk **Poziom** (u góry) otwiera okno: wpisz numer zlecenia albo użyj „–”/„+” i naciśnij **Zatwierdź**. Wybrany poziom zapisuje się jako bieżący postęp.

Przycisk jest widoczny tylko w edytorze i w wersjach testowych (debug). W wersji eksportowanej do sklepu (release) znika automatycznie.

## Zasady
- Robot bierze z góry palety wszystkie widoczne paczki tego samego produktu, ile zmieści się na palecie docelowej.
- Paczki stawia się na pustej palecie albo na tym samym produkcie.
- Gotowa paleta (pełna, jeden produkt) zapala zieloną lampkę.
- **Cofnij** – bez limitu. **Od nowa** – restart zlecenia.
- **Podpowiedź** – pokazuje następny ruch („Z” → „NA”). W ślepym zaułku mówi, ile ruchów cofnąć. Zużywa 1 podpowiedź, chyba że nie ma czego podpowiedzieć.

## Utrudnienia i krzywa trudności
| Zlecenia | Co się dzieje |
|---|---|
| 1–15 | Rośnie liczba produktów: 3 → 8 |
| 18 | Nowość: **palety na 5** paczek |
| 23 | Nowość: **wymiana chwytaków** – próżnia (cały ciąg albo nic), widły (do 2), szczęki (1). Zmiana kosztuje ruch |
| 28 | Nowość: **śliskie paczki** – z szansą 4% paczka wyślizguje się i spada z powrotem; ruch przepada i nie da się go cofnąć. Przy limicie ruchów generator dolicza zapas |
| 33 | Nowość: **limit ruchów** – cofnięcie zwraca ruch |
| 41 | Nowość: **folia stretch** – paczki owinięte folią są ukryte, dopóki nie trafią na górę palety. Start od 20% owiniętych paczek, rośnie do 80% około zlecenia 150 |
| 44+ | Utrudnienia na przemian wg hierarchii (lżejsze częściej, folia rzadziej); pary z folią od 80, folia + limit od 110 |
| co 5. (od 10.) | Zlecenie „przerwa”: łatwiejsze, bez utrudnień |

Przy pierwszym wystąpieniu nowości gra pokazuje krótką planszę z wyjaśnieniem. Natężenie (ile paczek w folii, jak ciasny limit) rośnie powoli do ok. 90. zlecenia.

Trudność jest **mierzona**: generator rozgrywa każdego kandydata na poziom kilkanaście razy „rozsądnie losowo”. Jako zlecenie wybiera tego, którego odsetek ślepych zaułków jest najbliższy celowi. Wszystkie liczby można stroić w `scripts/level_generator.gd`.

**Uwaga:** krzywa jest ustawiona na wyczucie. Trzeba ją dostroić na podstawie testów z prawdziwymi graczami.

## Podpowiedzi i sklep
- **Za darmo:**
  - 3 na start;
  - +1 za każde 3 ukończone zlecenia;
  - +1 za dobrowolne obejrzenie reklamy;
  - **rzadkie znalezisko:** 0,3% szansy przy podniesieniu paczki, najwyżej raz na zlecenie. Cofanie i powtarzanie ruchów nie zwiększa szansy. Stała `FIND_HINT_CHANCE` w `scripts/main.gd`.
- **Do kupienia:** pakiety 5, 15 i 40 podpowiedzi (identyfikatory `hints_5`, `hints_15`, `hints_40` w `scripts/store.gd`).
- **Tryb testowy:** zakup i reklama są symulowane. Prawdziwe płatności (Google Play Billing) i reklamy (np. AdMob) to osobny etap. Wymagają konta Google Play Console, wtyczek do Godota i testów na telefonie.

## Grafika
- Wszystko jest rysowane kodem. Dochodzą: czcionka Exo 2, shader efektów obrazu (`assets/shaders/post.gdshader`: poświata, kolory, winieta, ziarno), głębia hali (świetliki, regały w tle, kurz), cieniowane kartony z naklejkami, prowadnik kablowy robota, diody stanu.
- Efekty obrazu można wyłączyć w menu („Efekty graficzne”), jeśli telefon nie daje rady.

## Licencje zasobów
- Czcionka **Exo 2** – SIL Open Font License 1.1 (`assets/fonts/OFL-Exo2.txt`). Plik licencji musi zostać dołączony do gry.
- Dźwięki – własne, wygenerowane skryptem `tools/make_sfx.py`.

## Struktura plików
| Plik | Do czego służy |
|---|---|
| `project.godot` | Ustawienia: pion 720×1280, renderer zgodny ze starszymi telefonami, autoloady |
| `scenes/main.tscn` | Scena startowa |
| `scripts/board.gd` | Zasady gry: ruchy, folia, cofanie, wygrana |
| `scripts/solver.gd` | Szukanie rozwiązania: sprawdzanie poziomów, limit ruchów, podpowiedzi |
| `scripts/level_generator.gd` | Zlecenia, krzywa trudności, utrudnienia |
| `scripts/hint_wallet.gd` | Licznik podpowiedzi i nagrody |
| `scripts/decor.gd` | Katalog ozdób hali (nazwy, ceny w gwiazdkach) |
| `scripts/star_row.gd` | Gwiazdki rysowane kodem |
| `scripts/feedback.gd` | Autoload `Feedback` – wysyłka ankiet do arkusza Google (adres i klucz do uzupełnienia), kolejka offline |
| `scripts/levels.gd` | Autoload `Levels` – wczytuje gotowe poziomy z `data/levels.json` |
| `data/levels.json` | Zlecenia 1–150 i programy 1–60 wyliczone z góry |
| `tools/precompute_levels.gd` | Narzędzie do ponownego wyliczenia `data/levels.json` |
| `scripts/save_data.gd` | Autoload `Save` – zapis postępu i ustawień |
| `scripts/store.gd` | Autoload `Store` – sklep i reklamy (tryb testowy) |
| `scripts/sound.gd` | Autoload `Sfx` – efekty dźwiękowe |
| `scripts/main.gd` | Rysowanie hali i robota, dotyk, animacje, logika rozgrywki |
| `scripts/hud.gd` | Przyciski, okna: sklep, wygrana, nowość, ładowanie |
| `scripts/fx.gd` | Iskry, konfetti, unoszące się napisy |
| `assets/sfx/*.wav` | Dźwięki (własne, syntetyczne, łagodne). Głośność ogólna: `VOLUME_DB` w `scripts/sound.gd` |
| `tools/make_sfx.py` | Generator dźwięków |
| `tests/run_tests.gd` | Testy automatyczne |

**Gotowe poziomy:** zlecenia 1–150 i programy 1–60 są wyliczone z góry i zapisane w `data/levels.json`, więc telefon nie musi ich liczyć. **Po każdej zmianie w `level_generator.gd` uruchom ponownie:**
```bash
godot --headless --script res://tools/precompute_levels.gd -- --campaign=150 --programs=60
```
Test automatyczny wykrywa, gdy plik nie zgadza się z generatorem.

Dalsze zlecenia liczą się **w tle** (osobny wątek): następne przygotowuje się, gdy gracz rozwiązuje bieżące. Przygotowanie trudnego zlecenia trwało do ok. 3 s na serwerze testowym. Na słabym telefonie może trwać dłużej, wtedy pokaże się „Przygotowuję zlecenie…”.

## Testy automatyczne
W folderze projektu (`godot` = ścieżka do programu Godot):
```bash
godot --headless --import
```
```bash
godot --headless --script res://tests/run_tests.gd
```
Testy sprawdzają:
- zasady ruchu, folię, cofanie, limit głębokości solvera i licznik podpowiedzi;
- zlecenia 1–60: komplet paczek, powtarzalność, zgodność utrudnień, rozwiązywalność w limicie ruchów.

Oczekiwany wynik: `błędów: 0`. Zakres można zmienić dopisując `-- --levels=90` (trwa dłużej).

## Uruchomienie na telefonie z Androidem (do testów)
1. Godot: **Editor → Manage Export Templates → Download and Install** (wersja musi być zgodna z edytorem: 4.7.2).
2. Zainstaluj **JDK 17** i **Android SDK**, ścieżki wpisz w **Editor → Editor Settings → Export → Android**.
3. **Project → Export → Add… → Android** → eksport `.apk` → zainstaluj na telefonie.

Przeprowadzę Cię przez to osobno. Pliku `.aab` i klucza podpisu do Google Play jeszcze nie twórz.

## Plan testu prototypu
- Daj grę 5–10 osobom bez tłumaczenia zasad.
- Zapisz:
  1. czy zrozumiały zasady;
  2. do którego zlecenia doszły;
  3. ile minut grały;
  4. gdzie się frustrowały;
  5. czy użyłyby podpowiedzi i czy rozważyłyby zakup.
- Decyzja: grają dłużej i wracają → MVP z prawdziwymi płatnościami. Nudzą się lub frustrują → korekta krzywej trudności lub mechaniki.
