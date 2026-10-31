# Hierarchia utrudnień – pomiar i decyzje

Data pomiaru: 31.10.2026, narzędzie `tools/analyze_modifiers.gd` (powtarzalne – uruchom po każdej zmianie zasad).

## Metoda
- **24 te same plansze bazowe** (6 produktów, palety na 4, 2 puste palety); na każdą nakładamy po kolei jedno utrudnienie.
- **Mądry gracz (pełna wiedza):** liczba ruchów krótkiego rozwiązania.
- **Gracz z niepełną wiedzą** (tylko dla folii): zgaduje zawartość folii zgodnie z tym, co widać, planuje, a gdy odsłonięta paczka okaże się inna – planuje od nowa; gdy plan nie istnieje – cofa ruch. To przybliża prawdziwego gracza, który nie widzi pod folię.
- **Ślepe zaułki:** odsetek nieudanych gier „rozsądnie losowego” gracza (miara z generatora).
- **Ograniczenia:** to model komputerowy, nie ludzie. Prawdziwe odczucia trzeba potwierdzić ankietą w grze (pytanie o trudność + zlecenie, na którym gracz jest).

## Wyniki
| Utrudnienie | Ruchy mądrego gracza | vs baza | Ślepe zaułki (losowy) | Gracz bez wiedzy: ruchy / cofnięcia |
|---|---|---|---|---|
| Brak (baza) | 19,2 | – | 39% | – |
| Chwytaki | 19,8 | +3% | 30% | – |
| Palety na 5 | 19,7 | +2% | 20% | – |
| Folia 35% paczek | 19,6 | +2% | 43% | **26,2 (+36%) / 0,7** |
| Folia 60% paczek | 20,1 | +5% | 38% | **29,0 (+51%) / 1,8** |
| Folia 90% paczek | 20,7 | +8% | 40% | **31,9 (+66%) / 2,9** |

**Limit ruchów** (nie zmienia planszy): limit = wzorzec + zapas 60% → 15%. Mądry gracz mieści się zawsze; gracz grający „na wyczucie” – coraz rzadziej. Karze nieefektywność.

**Śliskie paczki** (4% na ruch): przy 20 ruchach ≥1 upadek w 56% zleceń (średnio 0,8 straconego ruchu); przy 35 ruchach – 76% (1,4); przy 50 – 87% (2,0). Odczuwalne głównie razem z limitem; czysta losowość, więc łatwo o frustrację.

## Hierarchia (od najlżejszego)
1. **Palety na 5** – więcej miejsca, mniej ślepych zaułków. Świeżość bez kary.
2. **Chwytaki** – dodają decyzji (który chwytak, kiedy zmienić), koszt ruchów minimalny.
3. **Śliskie paczki** – mały, losowy koszt; uczy, że ruch może przepaść.
4. **Limit ruchów** – wymaga planowania; średnio ciężki.
5. **Folia stretch** – najcięższa: odbiera możliwość planowania; koszt rośnie z odsetkiem owiniętych paczek.

Najcięższe połączenia: **folia + limit** (brak informacji i brak zapasu ruchów), **śliskie + limit** (losowa porażka – dlatego limit ma zapas na upadki).

## Decyzje (wprowadzone w `scripts/level_generator.gd`)
| | Wcześniej | Teraz |
|---|---|---|
| Kolejność nowości | folia 18, limit 23, palety na 5 28, chwytaki 33, śliskie 41 | **palety na 5 – 18, chwytaki – 23, śliskie – 28, limit – 33, folia – 41** |
| Udział w zleceniach 1–150 | folia 16%, palety 14%, limit 13%, chwytaki 13%, śliskie 11% | **palety 19%, chwytaki 16%, limit 16%, śliskie 9%, folia 7%** |
| Folia – odsetek owiniętych | 35% → 90% (do zlecenia ~90) | **20% przy wprowadzeniu, 25% → 80% (do ~150)** |
| Pary utrudnień | dowolne, od zlecenia 43 | lekkie pary od 44; **pary z folią od 80; folia + limit od 110** |

## Co dalej
- Po testach z ludźmi porównać ankiety („za trudna”) z numerem zlecenia – jeśli skargi skupiają się przy konkretnym utrudnieniu, przesunąć je dalej lub zmniejszyć natężenie.
- Po każdej zmianie: `tools/analyze_modifiers.gd` → `tools/precompute_levels.gd` → testy.
