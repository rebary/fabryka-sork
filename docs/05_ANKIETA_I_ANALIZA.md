# Ankieta graczy – zbieranie i analiza w jednym miejscu

Ankieta jest **w grze** (menu → „Ankieta – podziel się wrażeniami”, a po 5 ukończonych zadaniach jednorazowe zaproszenie z opcją „Nie teraz”).
Odpowiedzi trafiają do **Twojego arkusza Google Sheets**, który od razu je **analizuje** (zakładka „Analiza”).
Koszt: 0 zł. Czas konfiguracji: ok. 10–15 minut, jednorazowo.

## Jak to działa
```
Gra (ankieta) --internet--> Google Apps Script (Twój skrypt) --> Arkusz: "Odpowiedzi" + "Analiza"
     |
     +-- bez internetu: ankieta czeka w kolejce na telefonie i wysyła się później
```

**Pytania w ankiecie:**
1. ocena gry (1–5 gwiazdek);
2. trudność (za łatwa / w sam raz / za trudna);
3. ulubiony tryb (kampania / programowanie / oba / żaden);
4. czy poleciłbyś grę (tak / może / nie);
5. co się podoba (tekst, opcjonalnie);
6. co poprawić (tekst, opcjonalnie).

**Dane dołączane automatycznie:** wersja gry, gdzie gracz był w chwili ankiety, numer zlecenia i programu, gwiazdki, podpowiedzi, liczba ukończonych zadań, łączny czas gry, model telefonu, system, język, losowy identyfikator instalacji. Gra **nie wysyła** imienia, e-maila ani lokalizacji.

---

## Konfiguracja krok po kroku
### 1. Utwórz arkusz
1. Wejdź na https://sheets.google.com → **Pusty arkusz**. Nazwij go np. „Fabryka Sort – ankiety”.

### 2. Wklej skrypt
1. W arkuszu: **Rozszerzenia → Apps Script**.
2. Usuń przykładowy kod i wklej całą zawartość pliku `docs/ankieta/Code.gs`.
3. W linii `const SHARED_KEY = 'ZMIEN_MNIE';` wpisz własny klucz, np. `fs-7Kq2-ankieta` (dowolny ciąg liter i cyfr).
4. Zapisz (ikona dyskietki).

### 3. Utwórz zakładki i analizę
1. U góry wybierz funkcję **setup** → **Uruchom**.
2. Google poprosi o uprawnienia („Ta aplikacja nie jest zweryfikowana” – to Twój własny skrypt): **Zaawansowane → Przejdź do projektu → Zezwól**.
3. W arkuszu pojawią się zakładki **Odpowiedzi** i **Analiza** z wykresami.
4. (Opcjonalnie) Uruchom **testPost** – w „Odpowiedziach” pojawi się wiersz testowy (potem możesz go usunąć).

### 4. Udostępnij skrypt grze
1. **Wdróż → Nowe wdrożenie** → typ: **Aplikacja internetowa**.
2. **Wykonaj jako: Ja**, **Kto ma dostęp: Każdy**.
3. **Wdróż** → skopiuj **adres URL aplikacji internetowej** (kończy się na `/exec`).
   - „Każdy” oznacza, że gra może wysyłać dane bez logowania. Arkusz **nie** staje się publiczny – widzisz go tylko Ty.

### 5. Wpisz adres i klucz w grze
W pliku `scripts/feedback.gd`:
```gdscript
const ENDPOINT_URL := "https://script.google.com/macros/s/.../exec"
const SHARED_KEY := "fs-7Kq2-ankieta"   # ten sam co w Code.gs
```

### 6. Pozwól grze na internet (Android)
W Godocie: **Project → Export → Android → Permissions →** zaznacz **Internet**. Bez tego ankiety na telefonie zostaną w kolejce.

### 7. Sprawdź
1. Uruchom grę (F5) → menu → Ankieta → wypełnij → Wyślij.
2. Po kilku sekundach wiersz pojawi się w zakładce „Odpowiedzi”, a „Analiza” przeliczy się sama.

---

## Co znajdziesz w zakładce „Analiza”
- liczba ankiet i unikalnych graczy;
- średnia ocena, średni czas gry, średnia liczba ukończonych zadań;
- **wskaźnik polecenia** (% „tak” minus % „nie”);
- rozkład ocen, trudności, ulubionego trybu i polecania (z wykresami);
- **wyniki według wersji gry** – widać, czy poprawki podniosły oceny;
- **30 najnowszych komentarzy** w jednym miejscu.

**Jak czytać wyniki (praktycznie):**
- Przy małej liczbie ankiet (np. poniżej 20) traktuj liczby jako sygnał, a nie pewny wynik – czytaj przede wszystkim komentarze.
- Dużo „za trudna” razem z niskim czasem gry = za szybki wzrost trudności (stroimy `level_generator.gd`).
- Wysoka ocena trybu programowania = argument za jego rozwijaniem (i za pomysłem na grę z wieloma ramionami).

## Zmiany w skrypcie później
Po każdej zmianie w `Code.gs`: **Wdróż → Zarządzaj wdrożeniami → edytuj (ołówek) → Wersja: Nowa wersja → Wdróż**. Adres `/exec` zostaje ten sam.

## Prywatność i Google Play (ważne)
- Ankieta jest dobrowolna i anonimowa, ale pola tekstowe mogą zawierać to, co gracz wpisze – dlatego gra prosi, by nie wpisywać danych osobowych.
- **Polityka prywatności** gry musi opisywać ankietę: jakie dane, po co (ulepszanie gry), gdzie są przechowywane (Google Sheets na koncie twórcy), jak długo, kontakt w sprawie usunięcia (podaj losowy ID instalacji – jest w arkuszu).
- W formularzu **„Bezpieczeństwo danych”** w Play Console zaznacz zbieranie danych typu **opinie w aplikacji** i **informacje o urządzeniu / identyfikatory** – zbierane opcjonalnie, w celu analityki/ulepszania aplikacji, przesyłane szyfrowanie (HTTPS), nieudostępniane podmiotom trzecim.
- W razie wątpliwości co do RODO skonsultuj się ze specjalistą – to nie jest porada prawna.

## Bezpieczeństwo (ograniczenia)
- Klucz `SHARED_KEY` jest wbudowany w grę, więc zdeterminowana osoba może go odczytać i wysłać fałszywe ankiety. Skrypt odrzuca niepoprawne dane, duplikaty i zabezpiecza arkusz przed wstrzykiwaniem wzorów, ale **nie jest to ochrona przed celowym spamem**. Na etapie testów to wystarcza; przy dużej skali rozważymy usługę z limitowaniem zapytań.
