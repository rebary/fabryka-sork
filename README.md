# Fabryka Sort – prototyp

Gra logiczna w motywie automatyzacji produkcji. Robot-suwnica przenosi paczki z produktami między paletami. Cel: na każdej palecie ma zostać tylko jeden rodzaj produktu.

Nazwa jest robocza. Przed publikacją sprawdź, czy nie jest zajęta w Google Play i nie narusza cudzego znaku towarowego.

**Status:** prototyp do testów grywalności. To nie jest gotowy produkt: brak reklam, zakupów, dźwięku, menu i analityki.

## Wymagania
- **Godot 4.6.x, wersja standardowa** (nie .NET), z https://godotengine.org/download. Prototyp sprawdzono na 4.6.3.
- Na razie nic więcej. Grafika jest rysowana kodem, więc projekt nie potrzebuje plików graficznych ani dodatków.

## Uruchomienie na komputerze
1. Rozpakuj folder `fabryka_sort` w dowolnym miejscu.
2. Uruchom Godota → **Import** → wskaż plik `project.godot` → **Import & Edit**.
3. Naciśnij **F5** (albo ▶ w prawym górnym rogu). Otworzy się okno w proporcjach telefonu.
4. Sterowanie: kliknij paletę, z której robot ma wziąć paczki (podświetli się na niebiesko), a potem paletę docelową.

## Zasady gry
- Robot bierze z góry palety wszystkie paczki tego samego produktu, ile zmieści się na palecie docelowej.
- Paczki można postawić na pustej palecie albo na paczce tego samego produktu.
- Paleta mieści 4 paczki. Pełna paleta z jednym produktem dostaje zielony znaczek.
- **Cofnij** – cofa ruch (bez limitu).
- **Od nowa** – restart zlecenia.
- **Podpowiedź** – pokazuje następny ruch („Z” → „NA”). W ślepym zaułku mówi, ile ruchów trzeba cofnąć.
- Postęp (numer zlecenia) zapisuje się automatycznie.

## Struktura plików
| Plik | Do czego służy |
|---|---|
| `project.godot` | Ustawienia projektu: pion, 720×1280, renderer zgodny ze starszymi telefonami |
| `scenes/main.tscn` | Scena startowa (tylko węzeł z podpiętym skryptem) |
| `scripts/board.gd` | Zasady gry: ruchy, cofanie, sprawdzanie wygranej. Bez grafiki, więc łatwo ją testować |
| `scripts/solver.gd` | Szuka rozwiązania: sprawdza poziomy i daje podpowiedzi |
| `scripts/level_generator.gd` | Tworzy poziomy z numeru zlecenia. Co 3 poziomy dochodzi nowy produkt (3–8) |
| `scripts/main.gd` | Rysowanie, dotyk, animacja robota, przyciski, zapis |
| `tests/run_tests.gd` | Automatyczne testy logiki |

## Testy automatyczne
W terminalu, w folderze projektu (`godot` = ścieżka do pliku programu Godot):
```bash
godot --headless --import
```
```bash
godot --headless --script res://tests/run_tests.gd
```
Oczekiwany wynik: `Sprawdzeń: 1139, błędów: 0`.

Test sprawdza zasady ruchu, cofanie, wykrywanie wygranej oraz poziomy 1–30: czy mają komplet paczek, czy są powtarzalne i czy każdy da się rozwiązać.

## Uruchomienie na telefonie z Androidem (do testów)
Najprostsza droga, bez Android Studio:
1. W Godocie: **Editor → Manage Export Templates → Download and Install**.
2. Zainstaluj **JDK 17** i **Android SDK**, a ich ścieżki wpisz w **Editor → Editor Settings → Export → Android**.
3. **Project → Export → Add… → Android** i zapisz `.apk`.
4. Skopiuj plik `.apk` na telefon i zainstaluj go (telefon poprosi o zgodę na instalację z nieznanego źródła).

Ten krok wymaga konfiguracji na Twoim komputerze. Przeprowadzę Cię przez niego osobno, krok po kroku. Pliku `.aab` do Google Play i klucza podpisu nie twórz jeszcze teraz.

## Co dalej (plan testu prototypu)
- Daj grę 5–10 osobom bez tłumaczenia zasad i patrz, jak grają.
- Zapisz:
  1. czy zrozumiały zasady same;
  2. do którego zlecenia doszły;
  3. ile minut grały bez zachęcania;
  4. czy chcą grać dalej.
- Decyzja:
  - grają dłużej i wracają → rozbudowa do MVP;
  - nudzą się szybko → zmiana lub dodanie mechaniki wyróżniającej (np. taśmociąg dowożący nowe paczki, limit ruchów robota).
