# Start testów z graczami – lista kroków

Cel pierwszej rundy: **3–5 osób gra przez tydzień**, a Ty dostajesz odpowiedzi z ankiet w jednym arkuszu.
Wersja: 0.9.1 (plik `FabrykaSort.html`, bez przycisków testowych).

## Dwa pliki – nie pomyl
| Plik | Dla kogo | Różnica |
|---|---|---|
| `FabrykaSort_dla_mnie.html` | tylko Ty | przyciski „Test: …” (wybór poziomu, gwiazdki bez limitu) |
| `FabrykaSort.html` | testerzy | bez przycisków testowych – wyniki ankiet są wiarygodne |

Sklep i reklamy w obu plikach działają w **trybie testowym** (bez pieniędzy) – testerzy mogą sprawdzić zakupy bez płacenia.

---

## Krok 1. Podłącz ankiety (ok. 15 min) – KONIECZNIE przed wysłaniem
Bez tego ankiety zostaną w przeglądarkach testerów i do Ciebie nie dotrą.
1. Załóż arkusz i wdroż skrypt wg `docs/05_ANKIETA_I_ANALIZA.md` (kroki 1–4).
2. Wpisz adres `/exec` i klucz w `scripts/feedback.gd` (albo wklej je mi – podłączę i przebuduję pliki).
3. Zbuduj pliki ponownie (z folderu projektu):
   ```bash
   godot --headless --export-release "Web" build/web_release/index.html
   ```
   ```bash
   python3 tools/build_single_html.py build/web_release FabrykaSort.html
   ```

## Krok 2. Sprawdź sam (ok. 20 min)
- [ ] Otwórz `FabrykaSort.html` w Chrome lub Edge (dwuklik).
- [ ] Zagraj 2–3 zlecenia, 1 program, 1 pojedynek z rywalem.
- [ ] Wypełnij ankietę w grze → po kilku sekundach wiersz jest w zakładce „Odpowiedzi” arkusza. **Jeśli nie ma – nie wysyłaj jeszcze gry, napisz do mnie** (to jedyna rzecz, której nie mogłem sprawdzić bez Twojego konta Google).
- [ ] Utwórz wyzwanie kodem i przyjmij je w drugiej przeglądarce (np. Edge) – sprawdzisz pojedynek między ludźmi.

## Krok 3. Wybierz testerów (3–5 osób)
- Różne osoby: ktoś grający w gry na telefonie, ktoś „niegrający”, ktoś z branży automatyki.
- Każdy potrzebuje komputera z Chrome lub Edge (wersja na telefon będzie w następnej rundzie – APK).
- Zapisz listę – te same osoby przydadzą się do testu zamkniętego w Google Play (potrzeba tam 12+).

## Krok 4. Wyślij grę
Wrzuć `FabrykaSort.html` na Google Drive (udostępnianie „każdy z linkiem”) i wyślij wiadomość:

> Cześć! Robię grę logiczną na telefon i szukam kilku osób do pierwszych testów.
> 1. Pobierz plik: [LINK]
> 2. Otwórz go dwuklikiem w Chrome lub Edge (działa bez internetu i bez instalacji).
> 3. Graj jak chcesz przez kilka dni – kampania, programowanie robota, pojedynki.
> 4. Po kilku zleceniach gra zaproponuje krótką ankietę (6 pytań) – to dla mnie najważniejsze. Ankieta jest też w menu.
> 5. Jeśli chcesz, wyzwij mnie w pojedynku – w menu „Pojedynek → Wyzwij znajomego” dostaniesz kod do wysłania.
>
> Sklep jest w trybie testowym – nic nie kosztuje. Dzięki!

## Krok 5. Tydzień testów
- Dzień 2–3: krótkie przypomnienie o ankiecie (bez nacisku).
- Zapisuj też to, co testerzy powiedzą „przy okazji” (rozmowa, wiadomość) – często cenniejsze niż ankieta.
- Nie poprawiaj gry w trakcie tygodnia (chyba że błąd blokuje grę) – wyniki byłyby nieporównywalne.

## Krok 6. Analiza i decyzja (po tygodniu)
W arkuszu, zakładka „Analiza”. Prześlij mi eksport arkusza (CSV) albo zrzut – przeanalizujemy razem.

| Sygnał | Co oznacza | Co robimy |
|---|---|---|
| Co najmniej 3 z 5 osób: ocena 4–5, grały ≥10 min, „poleciłbym: tak/może” | gra wciąga | runda 2: APK na telefony + przygotowanie Google Play |
| Dużo „za trudna” + niskie zlecenie/program w ankiecie | za szybki wzrost trudności | strojenie krzywej (`level_generator.gd`) i powtórka z 2–3 nowymi osobami |
| Nikt nie wybiera jednego trybu jako ulubionego | tryb do przemyślenia | uproszczenie lub schowanie trybu przed premierą |
| Niska ocena mimo zrozumienia zasad | problem z „zabawą”, nie z interfejsem | rozmowa z testerami: co nudzi; zmiana kierunku przed dalszą pracą |

## Co potem (runda 2 i dalej)
1. Wersja APK na telefon (`docs/01_INSTALACJA_NA_TELEFONIE.md`) – potrzebny komputer z Android SDK albo odblokowanie w tej sesji adresów `dl.google.com` i `api.adoptium.net`.
2. Konto Google Play, polityka prywatności, test zamknięty 12+ osób przez 14 dni (`docs/02_PUBLIKACJA_GOOGLE_PLAY.md`).
3. Prawdziwe płatności i reklamy, ranking online (Google Play Games).
