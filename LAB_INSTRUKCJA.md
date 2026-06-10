# ALU zmiennoprzecinkowe - instrukcja na laboratorium

Ten dokument opisuje aktualny projekt `fp_alu`, schemat `demo.bdf`, generatory
liczb A/B oraz symulację w **University Program VWF**.

## 1. Najważniejsze informacje

- Top-level projektu: `demo`
- Schemat główny: `demo.bdf`
- Zegar: `CLOCK_50`, 50 MHz, okres 20 ns
- Operacja ALU: `SW[1..0]`
- Podgląd LED: `SW[3..2]`
- Reset wewnętrzny wszystkich bloków jest **active-high**
- W aktualnym `demo.bdf` nie ma bramki `NOT`
- Do symulacji `DIV_MAX` w `clk_div` powinien wynosić `6`
- Przed wgraniem na płytkę `DIV_MAX` powinien wrócić do `12500000`

Aktualna polaryzacja resetu bez bramki `NOT`:

```text
KEY[0] = 1 -> reset aktywny
KEY[0] = 0 -> układ pracuje
```

Na fizycznej płytce DE2-115 przycisk `KEY[0]` jest active-low. Przed
uruchomieniem na płytce należy więc ponownie dodać bramkę `NOT`:

```text
KEY[0] -> NOT -> reset wszystkich bloków
```

## 2. Cel układu

Układ pobiera dwie liczby zmiennoprzecinkowe A i B oraz wykonuje jedną
z trzech operacji:

| `SW[1..0]` | Operacja |
|---|---|
| `00` | A + B |
| `01` | A - B |
| `10` | A * B |
| `11` | Nie używać; obecnie zachowuje się jak odejmowanie |

Liczby A i B są generowane automatycznie przez dwa liczniki. A zmienia się
szybko, a B wykonuje jeden krok dopiero po pełnym obiegu A. W ten sposób
układ przechodzi przez wszystkie 16 x 16 = 256 par wejściowych.

## 3. Format liczby

Projekt nie używa standardu IEEE 754. Jedna liczba ma postać:

```text
wartość = mantysa * 2^wykładnik
```

Typ `fp_t` zawiera:

```vhdl
type fp_t is record
    mantissa : signed(15 downto 0);
    exponent : signed(15 downto 0);
end record;
```

Mantysa jest 16-bitową liczbą ze znakiem w U2, interpretowaną jako Q1.15:

```text
mantysa = signed_integer / 32768
```

Przykłady:

| Hex mantysy | Wartość mantysy |
|---|---:|
| `0000` | 0 |
| `1000` | +0.125 |
| `2000` | +0.25 |
| `4000` | +0.5 |
| `6000` | +0.75 |
| `7000` | +0.875 |
| `8000` | -1 |
| `A000` | -0.75 |
| `C000` | -0.5 |
| `E000` | -0.25 |
| `F000` | -0.125 |

Przykładowa kompletna liczba:

```text
mantysa = 4000 = +0.5
wykładnik = -2
wartość = 0.5 * 2^-2 = 0.125
```

Dlatego wejście `1000, exponent=0` oraz wynik `4000, exponent=-2`
reprezentują tę samą wartość 0.125.

## 4. Co robią bloczki

### `clk_div`

Dzieli zegar 50 MHz i generuje impuls `tick` trwający jeden cykl zegara.

```text
tick co (DIV_MAX + 1) cykli CLOCK_50
```

Ustawienia:

| Zastosowanie | `DIV_MAX` | Okres tick |
|---|---:|---:|
| Symulacja VWF | `6` | 7 * 20 ns = 140 ns |
| Płytka 50 MHz | `12500000` | około 0.25 s |

`tick` steruje licznikiem A i blokiem `start_delay`.

### `fp_counter_bdf`

Jest wrapperem BDF dla właściwego licznika `fp_counter`.

Quartus II nie potrafi wygenerować symbolu BDF z portem typu rekord `fp_t`.
Wrapper rozdziela rekord na zwykłe magistrale:

```text
value_mantissa[15..0]
value_exponent[15..0]
```

Porty:

| Port | Znaczenie |
|---|---|
| `clk` | zegar 50 MHz |
| `reset` | synchroniczny reset active-high |
| `en` | impuls powodujący następny krok |
| `value_mantissa` | mantysa wygenerowanej liczby |
| `value_exponent` | wykładnik; zawsze 0 |
| `carry` | impuls po pełnym obiegu licznika |

### Generator A

`en` generatora A jest podłączone do `tick`.

Sekwencja A:

```text
0000 -> 1000 -> 2000 -> 3000
     -> 4000 -> 5000 -> 6000 -> 7000
     -> 8000 -> 9000 -> A000 -> B000
     -> C000 -> D000 -> E000 -> F000
     -> 0000 -> ...
```

Wartości:

```text
0, +1/8, +2/8, ... +7/8, -1, -7/8, ... -1/8, 0
```

Przejście `7000 -> 8000` jest naturalnym przepełnieniem kodu U2:

```text
+0.875 -> -1
```

### Generator B

Generator B jest identyczny, ale:

```text
licznik_A.carry -> licznik_B.en
```

B zmienia się dopiero po pełnych 16 krokach A. Układ działa jak licznik
kilometrów:

```text
A: zmienia się co tick
B: zmienia się po pełnym obiegu A
```

W symulacji z `DIV_MAX=6`:

```text
A: krok co 140 ns
B: krok co 16 * 140 ns = 2.24 us
wszystkie 256 par: około 35.84 us
```

Na płytce z `DIV_MAX=12500000`:

```text
A: krok co około 0.25 s
B: krok co około 4 s
wszystkie 256 par: około 64 s
```

### `start_delay`

Opóźnia `tick` o jeden cykl zegara:

```text
tick -> rejestr -> start
```

Jest to potrzebne, ponieważ na zboczu z `tick=1` liczniki dopiero aktualizują
A i B. ALU powinno zatrzasnąć nowe wartości w następnym cyklu.

Bez `start_delay` ALU mogłoby obliczać wynik dla poprzedniej pary A/B.

### `alu_bdf`

Jest wrapperem BDF dla właściwego modułu `alu`.

Wrapper:

1. odbiera zwykłe magistrale z BDF,
2. zamienia je na rekordy `fp_t`,
3. uruchamia `alu`,
4. rozdziela rekord wyniku na dwie magistrale.

Porty:

| Port | Znaczenie |
|---|---|
| `clk` | zegar |
| `reset` | reset active-high |
| `start` | impuls rozpoczęcia obliczenia |
| `op[1..0]` | wybór operacji |
| `a_mantissa`, `a_exponent` | liczba A |
| `b_mantissa`, `b_exponent` | liczba B |
| `result_mantissa`, `result_exponent` | wynik |
| `done` | impuls, gdy wynik jest gotowy |

Wewnątrz `alu` moduły `fp_add_sub` oraz `fp_mul` istnieją równolegle.
Multiplekser wybiera wynik zgodnie z `op`.

### `fp_add_sub`

Dodawanie i odejmowanie wykonuje automat stanów:

```text
IDLE -> ALIGN -> COMPUTE -> NORMALIZE -> IDLE
```

Kroki:

1. zatrzaśnięcie A i B,
2. wyrównanie wykładników,
3. dodanie albo odjęcie mantys,
4. obsługa przepełnienia,
5. normalizacja wyniku.

Wynik jest gotowy po kilku cyklach zegara. `done` jest wtedy ustawione
na 1 przez jeden cykl.

### `fp_mul`

Mnożenie wykonuje:

```text
mantysa_wyniku = mantysa_A * mantysa_B
wykładnik_wyniku = wykładnik_A + wykładnik_B
```

Następnie wynik jest normalizowany. Automat ma stany:

```text
IDLE -> COMPUTE -> NORMALIZE -> IDLE
```

### `fp_normalize`

Normalizuje wynik bez zmiany jego wartości.

Dla niezerowego wyniku mantysa jest przesuwana w lewo, dopóki nie osiągnie
odpowiedniego zakresu. Każde przesunięcie mantysy razy 2 jest kompensowane:

```text
mantysa <<= 1
wykładnik -= 1
```

Przykład:

```text
1000, exponent=0
-> 2000, exponent=-1
-> 4000, exponent=-2
```

Wszystkie trzy zapisy reprezentują 0.125.

### `led_monitor_bdf`

Wybiera, co jest pokazane na `LEDR[15..0]`:

| `SW[3..2]` | `LEDR[15..0]` |
|---|---|
| `00` | mantysa wyniku ALU |
| `01` | mantysa A |
| `10` | mantysa B |
| `11` | mantysa wyniku ALU |

`LEDG[8..0]` zawsze pokazuje dziewięć najmłodszych bitów wykładnika wyniku.

## 5. Połączenie `demo.bdf`

### Zegar

`CLOCK_50` należy podłączyć do:

```text
clk_div.clk
licznik_A.clk
licznik_B.clk
start_delay.clk
alu_bdf.clk
```

### Reset - aktualna wersja bez `NOT`

`KEY[0]` należy podłączyć bezpośrednio do:

```text
clk_div.reset
licznik_A.reset
licznik_B.reset
start_delay.reset
alu_bdf.reset
```

W tej wersji:

```text
KEY=1 -> reset
KEY=0 -> praca
```

### Sterowanie generatorów

```text
clk_div.tick -> licznik_A.en
clk_div.tick -> start_delay.tick
licznik_A.carry -> licznik_B.en
```

Wyjście `carry` licznika B może pozostać niepodłączone.

### Wejścia ALU

```text
licznik_A.value_mantissa -> alu_bdf.a_mantissa
licznik_A.value_exponent -> alu_bdf.a_exponent

licznik_B.value_mantissa -> alu_bdf.b_mantissa
licznik_B.value_exponent -> alu_bdf.b_exponent

start_delay.start -> alu_bdf.start
SW[1..0]          -> alu_bdf.op[1..0]
```

### Monitor LED

```text
SW[3..2]                    -> led_monitor_bdf.sel[1..0]
licznik_A.value_mantissa    -> led_monitor_bdf.a_mantissa
licznik_B.value_mantissa    -> led_monitor_bdf.b_mantissa
alu_bdf.result_mantissa     -> led_monitor_bdf.result_mantissa
alu_bdf.result_exponent     -> led_monitor_bdf.result_exponent

led_monitor_bdf.ledr -> LEDR[15..0]
led_monitor_bdf.ledg -> LEDG[8..0]
```

### Wyjścia diagnostyczne do VWF

Magistrale należy również wyprowadzić na piny top-level:

```text
licznik_A.value_mantissa -> A_MANTISSA[15..0]
licznik_A.value_exponent -> A_EXPONENT[15..0]
licznik_B.value_mantissa -> B_MANTISSA[15..0]
licznik_B.value_exponent -> B_EXPONENT[15..0]

alu_bdf.result_mantissa -> RESULT_MANTISA[15..0]
alu_bdf.result_exponent -> RESULT_EXPONENT[15..0]
alu_bdf.done            -> DONE
```

Uwaga: w aktualnym schemacie pin ma nazwę `RESULT_MANTISA` z jednym `S`.
Jest to tylko literówka w nazwie pinu diagnostycznego.

## 6. Linie zwykłe i magistrale w BDF

Pojedyncze sygnały należy łączyć zwykłą linią:

```text
clk, reset, tick, start, carry, done
```

Sygnały wielobitowe należy łączyć linią magistrali:

```text
op[1..0]
mantissa[15..0]
exponent[15..0]
LEDR[15..0]
LEDG[8..0]
```

Jeżeli Quartus zgłasza niezgodność szerokości, należy sprawdzić:

1. czy użyto linii magistrali,
2. czy obie strony mają ten sam zakres,
3. czy nazwa ma format `[15..0]`, a nie `[15:0]`,
4. czy połączenie rzeczywiście dotyka końcówki portu.

## 7. Przygotowanie University Program VWF

### Kompilacja projektu

1. Otworzyć `fp_alu.qpf`.
2. Sprawdzić, czy `demo.bdf` jest top-level:
   `prawy przycisk -> Set as Top-Level Entity`.
3. Sprawdzić w `clk_div`, czy `DIV_MAX=6`.
4. Zapisać `demo.bdf`.
5. Uruchomić `Processing -> Start Compilation`.

W raporcie powinno być:

```text
Elaborating entity "demo" for the top level hierarchy
```

### Utworzenie VWF

1. `File -> New -> University Program VWF`.
2. `Edit -> End Time -> 50 us`.
3. `Edit -> Grid Size -> 20 ns`.
4. `Edit -> Insert -> Insert Node or Bus`.
5. `Node Finder`.
6. Filtr `Pins: all`.
7. Dodać:

```text
CLOCK_50
KEY
SW[3..0] lub osobno SW[0], SW[1], SW[2], SW[3]
A_MANTISSA[15..0]
A_EXPONENT[15..0]
B_MANTISSA[15..0]
B_EXPONENT[15..0]
RESULT_MANTISA[15..0]
RESULT_EXPONENT[15..0]
DONE
```

Można również dodać:

```text
LEDR[15..0]
LEDG[8..0]
```

### Ustawienie zegara

Dla `CLOCK_50`:

```text
Period: 20 ns
Duty cycle: 50%
Offset: 0
```

Przy widoku wielu mikrosekund zegar wygląda jak jednolity gęsty pasek.
Po powiększeniu powinien być widoczny prostokąt zmieniający stan co 10 ns.

### Ustawienie resetu bez `NOT`

W aktualnym schemacie:

```text
0 ns - 200 ns: KEY = 1
od 200 ns:     KEY = 0
```

Jeżeli `KEY=1` pozostanie do końca, wszystko będzie stale wyzerowane.

### Ustawienie operacji

Na pierwszy test:

```text
SW[1]=0
SW[0]=0
```

czyli dodawanie.

`SW[3..2]` wpływa tylko na `LEDR`, nie na wyjścia diagnostyczne.

### Format wyświetlania

Zalecane ustawienia:

```text
A_MANTISSA, B_MANTISSA, RESULT_MANTISA:
    Radix -> Hexadecimal

A_EXPONENT, B_EXPONENT, RESULT_EXPONENT:
    Radix -> Signed Decimal

DONE:
    Binary
```

### Uruchomienie

```text
Simulation -> Run Functional Simulation
```

Symulacja:

1. generuje testbench z wartości ustawionych w VWF,
2. podaje zegar, reset i przełączniki na top-level `demo`,
3. uruchamia model układu,
4. zapisuje wartości wyjść w czasie.

Oryginalny plik VWF zawiera wymuszenia wejść. Wynik symulacji jest również
zapisywany w:

```text
simulation/qsim/fp_alu.sim.vwf
```

## 8. Oczekiwane przebiegi

### A i B

Po zwolnieniu resetu A powinno zmieniać się co około 140 ns:

```text
0000, 1000, 2000, 3000, 4000, 5000, 6000, 7000,
8000, 9000, A000, B000, C000, D000, E000, F000,
0000, ...
```

B pozostaje `0000` przez cały pierwszy obieg A. Po 16 krokach:

```text
A = 0000
B = 1000
```

Potem A ponownie wykonuje pełny cykl, a B pozostaje `1000`.

### Wykładniki generatorów

Przez całą symulację:

```text
A_EXPONENT = 0
B_EXPONENT = 0
```

Jest to poprawne. Generatory tworzą piłę poprzez zmianę mantysy, a nie
wykładnika.

### `DONE`

`DONE` powinno pojawiać się jako krótki impuls o szerokości jednego okresu
zegara, czyli 20 ns.

Przy dużym oddaleniu może wyglądać jak cienka kreska albo być prawie
niewidoczne. Należy powiększyć przebieg.

### Wynik ADD, gdy B=0

Podczas pierwszego obiegu B wynosi 0, więc matematycznie:

```text
wynik = A + 0 = A
```

Kod wyniku może jednak różnić się od kodu wejścia przez normalizację.

| A mantysa | A wartość | Wynik mantysa | Wynik exponent |
|---|---:|---|---:|
| `0000` | 0 | `0000` | 0 |
| `1000` | +0.125 | `4000` | -2 |
| `2000` | +0.25 | `4000` | -1 |
| `3000` | +0.375 | `6000` | -1 |
| `4000` | +0.5 | `4000` | 0 |
| `5000` | +0.625 | `5000` | 0 |
| `6000` | +0.75 | `6000` | 0 |
| `7000` | +0.875 | `7000` | 0 |
| `8000` | -1 | `8000` | 0 |
| `C000` | -0.5 | `8000` | -1 |
| `E000` | -0.25 | `8000` | -2 |
| `F000` | -0.125 | `8000` | -3 |

Przykład:

```text
A = 1000, exponent=0
wynik = 4000, exponent=-2

0.125 = 0.5 * 2^-2
```

To jest poprawny wynik, a nie błąd.

### Przykładowe wyniki dla A i B

| A | B | Operacja | Oczekiwana wartość | Przykładowy wynik |
|---:|---:|---|---:|---|
| 0.125 | 0 | ADD | 0.125 | `4000`, exp `-2` |
| 0.125 | 0 | SUB | 0.125 | `4000`, exp `-2` |
| 0.125 | 0 | MUL | 0 | `0000`, exp `0` |
| 0.125 | 0.125 | ADD | 0.25 | `4000`, exp `-1` |
| 0.125 | 0.125 | SUB | 0 | `0000`, exp `0` |
| 0.125 | 0.125 | MUL | 0.015625 | `4000`, exp `-5` |
| 0.25 | 0.125 | ADD | 0.375 | `6000`, exp `-1` |
| 0.25 | 0.125 | SUB | 0.125 | `4000`, exp `-2` |
| 0.25 | 0.125 | MUL | 0.03125 | `4000`, exp `-4` |
| 0.5 | 0.5 | ADD | 1.0 | `4000`, exp `1` |
| 0.5 | 0.5 | SUB | 0 | `0000`, exp `0` |
| 0.5 | 0.5 | MUL | 0.25 | `4000`, exp `-1` |

## 9. Jak ręcznie sprawdzić wynik

### Krok 1: odczytaj mantysę

Dla dodatniej mantysy:

```text
mantysa = wartość_hex / 32768
```

Dla wartości z bitem 15 równym 1:

```text
signed_integer = wartość_hex - 65536
mantysa = signed_integer / 32768
```

Przykład `C000`:

```text
0xC000 = 49152
49152 - 65536 = -16384
-16384 / 32768 = -0.5
```

### Krok 2: zastosuj wykładnik

```text
wartość = mantysa * 2^exponent
```

Przykład:

```text
mantysa = 4000 = 0.5
exponent = -2
wartość = 0.5 * 2^-2 = 0.125
```

### Krok 3: porównaj matematycznie

```text
ADD: wynik = A + B
SUB: wynik = A - B
MUL: wynik = A * B
```

Nie należy porównywać wyłącznie kodu mantysy. Trzeba zawsze brać pod uwagę
również wykładnik.

## 10. Typowe problemy

### Wszystkie wyjścia są zerowe

Sprawdzić:

1. Czy `CLOCK_50` ma okres 20 ns.
2. Czy `DIV_MAX=6`.
3. Czy po zmianie BDF wykonano pełną kompilację.
4. Czy `demo` jest top-level.
5. Czy reset został zwolniony.

Bez `NOT`:

```text
0-200 ns: KEY=1
dalej:    KEY=0
```

### A robi jeden krok i wraca do zera

To zwykle błędna polaryzacja resetu. Taki efekt występuje, gdy układ najpierw
pracuje, a później reset pozostaje aktywny.

Sprawdzić, czy schemat zawiera `NOT`:

```text
bez NOT: KEY=1 resetuje
z NOT:   KEY=0 resetuje
```

### B długo pozostaje zerem

To jest poprawne. B wykonuje krok dopiero po 16 krokach A:

```text
16 * 140 ns = 2.24 us
```

### A i B exponent są stale równe 0

To jest poprawne. Generatory zmieniają wyłącznie mantysę.

### Wynik ma inną mantysę niż A, mimo że B=0

To efekt normalizacji. Porównać pełną wartość:

```text
mantysa * 2^exponent
```

### `DONE` wygląda jak stale 0

Impuls trwa tylko 20 ns. Powiększyć oś czasu.

### Błąd szerokości `SW`

Przykładowy błąd:

```text
Bus port "SW" specified in vector source file has width of 4,
which does not match width 16 of top level port
```

Naprawa:

1. ustawić `demo.bdf` jako top-level,
2. uruchomić pełną kompilację,
3. usunąć stary `SW` z VWF,
4. dodać ponownie `SW[3..0]` albo osobne bity.

### Nie można utworzyć symbolu z `alu.vhd`

Quartus II nie obsługuje portów typu rekord w generatorze symboli:

```text
Can't create symbol ... port "a" is not currently supported
```

Należy używać:

```text
alu_bdf.vhd -> alu_bdf.bsf
fp_counter_bdf.vhd -> fp_counter_bdf.bsf
```

### Symulacja jest bardzo wolna

Sprawdzić `clk_div`:

```text
symulacja: DIV_MAX=6
płytka:    DIV_MAX=12500000
```

### Ostrzeżenia o stałych wyjściach

Ostrzeżenia, że `A_EXPONENT` i `B_EXPONENT` są stale w GND, są oczekiwane,
ponieważ oba wykładniki generatorów są zawsze równe 0.

### Ostrzeżenia o nieprzypisanych pinach

Piny:

```text
A_MANTISSA, A_EXPONENT,
B_MANTISSA, B_EXPONENT,
RESULT_MANTISA, RESULT_EXPONENT, DONE
```

służą do symulacji VWF. Nie mają przypisanych fizycznych wyprowadzeń płytki,
więc Fitter może zgłaszać ostrzeżenia.

Przed docelowym wgraniem na płytkę najlepiej usunąć te dodatkowe piny
diagnostyczne i pozostawić `LEDR`, `LEDG`, `CLOCK_50`, `SW` oraz `KEY`.

## 11. Odtworzenie symboli

Jeżeli symbol zniknie lub zmienią się porty:

1. otworzyć odpowiedni plik `.vhd`,
2. `File -> Create/Update -> Create Symbol Files for Current File`,
3. w BDF wybrać `Insert Symbol -> Project`.

Potrzebne symbole:

```text
clk_div.bsf
fp_counter_bdf.bsf
start_delay.bsf
alu_bdf.bsf
led_monitor_bdf.bsf
```

## 12. Co powiedzieć prowadzącemu

Krótki opis projektu:

> ALU pracuje na własnym formacie zmiennoprzecinkowym: 16-bitowej mantysie
> Q1.15 ze znakiem oraz 16-bitowym wykładniku ze znakiem. Dwa generatory są
> zewnętrznym stopniem wejściowym. Generator A przechodzi przez 16 wartości
> dodatnich i ujemnych w kodzie U2, a generator B robi krok po pełnym obiegu A.
> Dzięki temu uzyskujemy wszystkie 256 kombinacji A i B. Impuls start jest
> opóźniony o jeden cykl, aby ALU zatrzasnęło już zaktualizowane wejścia.
> Dodawanie/odejmowanie oraz mnożenie działają równolegle, a multiplekser
> wybiera wynik. Wynik jest normalizowany, dlatego jego mantysa i wykładnik
> mogą mieć inny kod niż wejście, ale reprezentują poprawną wartość.

Dlaczego użyto wrapperów:

> Quartus II nie tworzy symboli BDF dla portów rekordowych `fp_t`, dlatego
> `alu_bdf` i `fp_counter_bdf` rozdzielają rekord na zwykłe magistrale mantysy
> oraz wykładnika.

Jak sprawdzana jest poprawność:

> W University Program VWF wymuszamy zegar, reset i kod operacji. Obserwujemy
> mantysę oraz wykładnik A, B i wyniku, a także impuls `DONE`. A zmienia się
> co tick, B po pełnym obiegu A. Wynik porównujemy jako
> `mantysa * 2^wykładnik`, a nie wyłącznie po samym kodzie mantysy.

## 13. Checklista przed pokazem

- [ ] `demo.bdf` jest top-level.
- [ ] Projekt kompiluje się bez błędów.
- [ ] `DIV_MAX=6` dla VWF.
- [ ] `CLOCK_50` ma okres 20 ns.
- [ ] Bez `NOT`: `KEY=1` przez 200 ns, potem `KEY=0`.
- [ ] `SW[1..0]=00` na pierwszy test ADD.
- [ ] Mantysy są wyświetlane w hex.
- [ ] Wykładniki są wyświetlane jako signed decimal.
- [ ] A wykonuje sekwencję `0000,1000,...,F000,0000`.
- [ ] B zmienia się po około 2.24 us.
- [ ] `DONE` pulsuje przez 20 ns.
- [ ] Wynik jest oceniany razem z wykładnikiem.
- [ ] Przed płytką: przywrócić `DIV_MAX=12500000`.
- [ ] Przed płytką: dodać `NOT` na `KEY[0]` albo inaczej poprawić reset.
