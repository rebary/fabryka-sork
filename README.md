# Fabryka Sort – prototyp

Gra logiczna w motywie automatyzacji produkcji. Robot-suwnica przenosi paczki z produktami między paletami. Cel: na każdej palecie ma zostać tylko jeden rodzaj produktu.

Nazwa jest robocza. Przed publikacją sprawdź, czy nie jest zajęta w Google Play i nie narusza cudzego znaku towarowego.

**Status:** prototyp do testów grywalności. To nie jest gotowy produkt. Sklep i reklamy działają tylko w **trybie testowym** (bez prawdziwych płatności i reklam).

## Wymagania
- **Godot 4.7.x, wersja standardowa** (nie .NET), z https://godotengine.org/download. Projekt sprawdzono na 4.7.2.
- Nic więcej do samej gry. Do ponownego wygenerowania dźwięków: Python 3 + numpy (opcjonalnie).

## Uruchomienie
1. Godot → **Import** → wskaż `project.godot` → **Import & Edit**.
2. **F5** (albo ▶). Okno ma proporcje telefonu.
3. Kliknij paletę, z której robot ma wziąć paczki (podświetli się na niebiesko), a potem paletę docelową.

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
| 18 | Nowość: **folia stretch** – paczki owinięte folią są ukryte, dopóki nie trafią na górę palety |
| 23 | Nowość: **limit ruchów** – cofnięcie zwraca ruch |
| 28 | Nowość: **palety na 5** paczek |
| 29+ | Utrudnienia na przemian (folia, limit, palety na 5), co 4. zlecenie para utrudnień |
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

## Struktura plików
| Plik | Do czego służy |
|---|---|
| `project.godot` | Ustawienia: pion 720×1280, renderer zgodny ze starszymi telefonami, autoloady |
| `scenes/main.tscn` | Scena startowa |
| `scripts/board.gd` | Zasady gry: ruchy, folia, cofanie, wygrana |
| `scripts/solver.gd` | Szukanie rozwiązania: sprawdzanie poziomów, limit ruchów, podpowiedzi |
| `scripts/level_generator.gd` | Zlecenia, krzywa trudności, utrudnienia |
| `scripts/hint_wallet.gd` | Licznik podpowiedzi i nagrody |
| `scripts/save_data.gd` | Autoload `Save` – zapis postępu i ustawień |
| `scripts/store.gd` | Autoload `Store` – sklep i reklamy (tryb testowy) |
| `scripts/sound.gd` | Autoload `Sfx` – efekty dźwiękowe |
| `scripts/main.gd` | Rysowanie hali i robota, dotyk, animacje, logika rozgrywki |
| `scripts/hud.gd` | Przyciski, okna: sklep, wygrana, nowość, ładowanie |
| `scripts/fx.gd` | Iskry, konfetti, unoszące się napisy |
| `assets/sfx/*.wav` | Dźwięki (własne, syntetyczne, łagodne). Głośność ogólna: `VOLUME_DB` w `scripts/sound.gd` |
| `tools/make_sfx.py` | Generator dźwięków |
| `tests/run_tests.gd` | Testy automatyczne |

Zlecenia liczą się **w tle** (osobny wątek): następne przygotowuje się, gdy gracz rozwiązuje bieżące. Przygotowanie trudnego zlecenia trwało do ok. 3 s na serwerze testowym. Na słabym telefonie może trwać dłużej, wtedy pokaże się „Przygotowuję zlecenie…”.

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
