# Arytmometr Zmiennoprzecinkowy na FPGA Cyclone II
## Kompletny przewodnik projektu

---

## Spis treści

1. [Czym jest VHDL i jak myśleć o kodzie sprzętowym](#1-czym-jest-vhdl)
2. [Składnia i konstrukcje VHDL używane w projekcie](#2-składnia-vhdl)
3. [Reprezentacja liczby zmiennoprzecinkowej](#3-reprezentacja-liczby)
4. [Architektura projektu — pliki i ich role](#4-architektura-projektu)
5. [Algorytmy — jak działają operacje](#5-algorytmy)
6. [Automat stanów (FSM)](#6-automat-stanów-fsm)
7. [Symulacja w ModelSim krok po kroku](#7-symulacja-w-modelsim)
8. [Wgrywanie na płytkę w Quartus](#8-wgrywanie-na-płytkę)
9. [Oczekiwane wyniki i jak je czytać](#9-oczekiwane-wyniki)

---

## 1. Czym jest VHDL

### VHDL to nie jest język programowania

Kiedy piszesz kod w C albo Pythonie, opisujesz **sekwencję instrukcji** które procesor wykona jedna po drugiej. VHDL działa zupełnie inaczej — opisujesz **strukturę sprzętu**: jakie elementy istnieją i jak są ze sobą połączone.

Kluczowe różnice:

| Programowanie (C) | Opis sprzętu (VHDL) |
|---|---|
| Kod wykonuje się sekwencyjnie | Wszystko działa **równolegle** — każdy moduł naraz |
| Zmienne przechowują wartości w RAM | Sygnały to **fizyczne draty** lub rejestry w układzie |
| Funkcje są wywoływane | Moduły są **instancjonowane** — istnieją cały czas |
| `x = 5` — zmiana natychmiastowa | `x <= 5` — zmiana na **następnym zboczu zegara** |

### Co to jest FPGA

FPGA (Field-Programmable Gate Array) to układ scalony wypełniony dziesiątkami tysięcy małych bloków logicznych, które można połączyć w dowolny sposób. VHDL opisuje **jak je połączyć** — kompilator tłumaczy kod na konfigurację tych połączeń.

Efekt: twój projekt `fp_add_sub`, `fp_mul` i `fp_normalize` istnieją **jednocześnie** w układzie jako osobne obwody. Nie ma procesora który "wywołuje" moduły — one wszystkie działają naraz.

### Zegar i synchroniczność

Większość układów cyfrowych jest **synchronicznych** — zmiany stanu dzieją się tylko w momencie narastającego zbocza sygnału zegarowego. Płytka Cyclone II ma zegar 50 MHz, co oznacza 50 milionów zboczy na sekundę — każde zbocze to jeden "krok" układu.

---

## 2. Składnia VHDL

### Biblioteki

```vhdl
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
```

Każdy plik zaczyna się od importu bibliotek. Bez nich VHDL nie zna nawet podstawowych typów.

- `std_logic_1164` — definiuje typy `std_logic` i `std_logic_vector`
- `numeric_std` — definiuje `signed`, `unsigned` i operacje arytmetyczne na nich (`+`, `-`, `*`, `shift_left`, `shift_right`, `resize`, `to_integer`, `to_signed`)

Zapis `use work.fp_pkg.all` importuje nasz własny pakiet z bieżącego projektu (`work` = aktualny projekt).

---

### Entity i Architecture

```vhdl
entity fp_add_sub is
    port (
        clk    : in  std_logic;
        result : out fp_t
    );
end entity;

architecture rtl of fp_add_sub is
    -- deklaracje sygnałów wewnętrznych
begin
    -- kod
end architecture;
```

**Entity** to **interfejs** modułu — odpowiednik nagłówka funkcji w C. Opisuje tylko wejścia i wyjścia (porty). Kierunki: `in` = wejście, `out` = wyjście, `inout` = dwukierunkowy.

**Architecture** to **implementacja** — ciało modułu. Jeden entity może mieć wiele architektur (np. różne implementacje tego samego interfejsu). Nazwa `rtl` (Register Transfer Level) to konwencja — mogłabyś napisać cokolwiek.

Między `is` a `begin` deklarujemy sygnały wewnętrzne. Między `begin` a `end` piszemy kod.

---

### Package

```vhdl
package fp_pkg is
    type fp_t is record ... end record;
    constant FP_ZERO : fp_t := ...;
end package;
```

Package to odpowiednik pliku nagłówkowego `.h` w C. Definiuje typy i stałe wspólne dla wszystkich modułów. Używany przez `use work.fp_pkg.all`.

---

### Typy danych

#### std_logic

Jeden bit sygnału. Może przyjmować wartości:
- `'0'` — logiczne zero
- `'1'` — logiczna jedynka
- `'Z'` — wysoką impedancja (odłączony)
- `'X'` — nieznana wartość (pojawia się w symulacji gdy dwa sterowniki konfliktu)

#### std_logic_vector

Wektor bitów bez interpretacji liczbowej. `std_logic_vector(15 downto 0)` to 16 bitów, bit 15 jest najstarszy (MSB), bit 0 najmłodszy (LSB). Używany głównie do podłączania do pinów płytki (LEDR, SW itp.).

#### signed i unsigned

Wektory bitów **z interpretacją liczbową**, z biblioteki `numeric_std`. Na nich można wykonywać operacje arytmetyczne `+`, `-`, `*`. `signed` używa kodu uzupełnienia do dwóch (U2), `unsigned` interpretuje jako liczbę bez znaku.

```vhdl
signal a : signed(15 downto 0);   -- liczba ze znakiem, zakres [-32768, +32767]
signal b : unsigned(7 downto 0);  -- liczba bez znaku, zakres [0, 255]
```

#### record

Struktura grupująca pola — odpowiednik `struct` w C.

```vhdl
type fp_t is record
    mantissa : signed(15 downto 0);
    exponent : signed(15 downto 0);
end record;

signal x : fp_t;
-- dostęp do pól:
x.mantissa <= to_signed(100, 16);
```

---

### Signal vs Variable

To jedna z najważniejszych różnic w VHDL.

**Signal** (sygnał):
- Deklarowany w architekturze, między `is` a `begin`
- Odpowiada fizycznemu dratowi lub rejestrowi w układzie
- Przypisanie `<=` **nie jest natychmiastowe** — nowa wartość jest zaplanowana, widoczna dopiero po zakończeniu bieżącego procesu (lub na następnym zboczu zegara w układach synchronicznych)

**Variable** (zmienna):
- Deklarowana wewnątrz `process`, po słowie `variable`
- Przypisanie `:=` jest **natychmiastowe** — nowa wartość dostępna od razu w tej samej linii poniżej
- Nie istnieje poza procesem — to lokalna wartość robocza

```vhdl
process(clk)
    variable v : integer := 0;  -- zmienna lokalna
begin
    v := 5;      -- natychmiastowe, v=5 już w następnej linii
    v := v + 1;  -- v=6
    sig <= v;    -- sygnał dostanie 6 po zakończeniu procesu
end process;
```

W projekcie używamy zmiennych (`variable`) do obliczeń wewnątrz procesu (np. iloczyn 32-bitowy w `fp_mul`), a sygnałów do przechowywania stanu między cyklami zegara.

---

### Process

```vhdl
process(lista_czułości)
    -- opcjonalne deklaracje zmiennych
begin
    -- kod sekwencyjny
end process;
```

Process to blok kodu który wykonuje się sekwencyjnie (linia po linii) — jak zwykła funkcja. Budzi się gdy zmieni się którykolwiek sygnał z listy czułości.

**Process kombinacyjny** — lista czułości zawiera wszystkie wejścia. Reaguje na każdą zmianę wejść, bez zegara:

```vhdl
process(a, b)   -- budzi się gdy a LUB b się zmieni
begin
    y <= a and b;
end process;
```

**Process synchroniczny** — lista czułości zawiera tylko zegar. Reaguje tylko na zbocze:

```vhdl
process(clk)
begin
    if rising_edge(clk) then
        -- to wykona się tylko na narastającym zboczu zegara
        reg <= data_in;
    end if;
end process;
```

`rising_edge(clk)` zwraca `true` gdy `clk` zmienia się z `'0'` na `'1'`.

---

### Przypisania poza procesem (concurrent)

Kod napisany **poza** procesem, bezpośrednio między `begin` a `end architecture`, działa jak ciągłe połączenie — jest zawsze aktywne:

```vhdl
y <= a and b;   -- y zawsze = a AND b, aktualizuje się natychmiast gdy a lub b się zmieni
```

To odpowiednik bramki logicznej podłączonej na stałe.

**`with ... select`** to kombinacyjny multiplekser:

```vhdl
with sel select
    y <= a when "00",
         b when "01",
         c when others;
```

Odpowiednik C: `y = (sel=="00") ? a : (sel=="01") ? b : c`

---

### Port map — instancjonowanie modułów

```vhdl
nazwa_instancji : entity work.nazwa_modułu
    port map (
        port_modułu => sygnał_lokalny,
        port2       => sygnał2
    );
```

To jak wstawienie układu scalonego do układu. `entity work.fp_normalize` oznacza: znajdź w projekcie (`work`) encję o nazwie `fp_normalize`. `port map` to "podłączenie nóżek" — lewa strona to nazwa portu w module, prawa to sygnał w bieżącym pliku.

Każde wywołanie `port map` tworzy **osobny, niezależny egzemplarz** modułu w układzie. `fp_add_sub` i `fp_mul` mają każdy swój własny `fp_normalize` działający równolegle.

---

### Przydatne funkcje z numeric_std

| Funkcja | Co robi | Przykład |
|---|---|---|
| `to_signed(n, w)` | Konwertuje integer `n` na `signed` o szerokości `w` | `to_signed(5, 16)` = 0x0005 |
| `to_integer(s)` | Konwertuje `signed`/`unsigned` na integer | `to_integer(x"0005")` = 5 |
| `resize(s, w)` | Zmienia szerokość `signed`/`unsigned` zachowując wartość (rozszerza znak) | `resize(s16, 17)` rozszerza 16→17 bitów |
| `shift_left(s, n)` | Przesuwa bity w lewo o n pozycji (= mnożenie przez 2^n) | `shift_left(x, 1)` = x*2 |
| `shift_right(s, n)` | Przesuwa bity w prawo o n pozycji, arytmetycznie (zachowuje znak) | `shift_right(x, 1)` = x/2 |
| `std_logic_vector(s)` | Konwertuje `signed` na `std_logic_vector` (bez zmiany bitów) | potrzebne do przypisania na wyjście LEDR |

---

### Literały liczbowe

```vhdl
42          -- dziesiętny
16#4000#    -- szesnastkowy (hex): 0x4000
2#1010#     -- binarny: 0b1010
x"4000"     -- hex w std_logic_vector: "0100000000000000"
'0'         -- jeden bit std_logic
"1010"      -- wektor bitów std_logic_vector
(others => '0')  -- wszystkie bity zerowe (niezależnie od szerokości)
```

---

### Assert i report (tylko symulacja)

```vhdl
assert WARUNEK
    report "Komunikat"
    severity ERROR;
```

Jeśli `WARUNEK = false`, ModelSim wypisuje komunikat. Poziomy: `NOTE`, `WARNING`, `ERROR`, `FAILURE`. Nie syntetyzuje się na FPGA — tylko do testowania.

---

## 3. Reprezentacja liczby

### Kod uzupełnienia do dwóch (U2)

To standardowy sposób kodowania liczb całkowitych ze znakiem w komputerach. Na N bitach:
- Zakres: od -2^(N-1) do +2^(N-1)-1
- Dla 16 bitów: -32768 do +32767
- Bit najstarszy (MSB) = bit znaku: 0 = dodatnia, 1 = ujemna
- Negacja: zaneguj wszystkie bity i dodaj 1

Przykłady 4-bitowe:
```
0111 = +7
0001 = +1
0000 =  0
1111 = -1
1000 = -8
```

### Ułamkowa interpretacja U2

Zamiast traktować 16-bitową liczbę U2 jako całkowitą (zakres [-32768, +32767]), **wyobrażamy sobie** że kropka dziesiętna stoi zaraz za bitem znaku:

```
bit15 . bit14 bit13 ... bit0
znak  ←  część ułamkowa →
```

Wartość = integer_U2 × 2^(-15)

Zakres: od -1.0 (gdy integer = -32768) do +0.99997 (gdy integer = +32767 ≈ 1 - 2^-15)

Przykłady:
```
0x4000 = 0100 0000 0000 0000 = +16384 jako int → +16384 × 2^(-15) = +0.5
0x6000 = 0110 0000 0000 0000 = +24576 jako int → +24576 × 2^(-15) = +0.75
0x8000 = 1000 0000 0000 0000 = -32768 jako int → -32768 × 2^(-15) = -1.0
0xC000 = 1100 0000 0000 0000 = -16384 jako int → -16384 × 2^(-15) = -0.5
```

**Ważne**: W VHDL nie robimy nic specjalnego — po prostu używamy normalnego `signed(15 downto 0)`. Interpretacja ułamkowa jest tylko w naszej głowie i w algorytmach.

### Format zmiennoprzecinkowy projektu

```
liczba = mantysa × 2^wykładnik
```

Gdzie:
- **mantysa** — `signed(15 downto 0)`, ułamkowa U2, zakres [-1, +1)
- **wykładnik** — `signed(15 downto 0)`, całkowita U2, zakres [-32768, +32767]

Razem: 32 bity na jedną liczbę.

Przykłady:
```
A: mantissa=0x4000 (+0.5), exponent=1  → wartość = 0.5 × 2^1 = 1.0
B: mantissa=0x4000 (+0.5), exponent=0  → wartość = 0.5 × 2^0 = 0.5
C: mantissa=0x6000 (+0.75), exponent=2 → wartość = 0.75 × 2^2 = 3.0
D: mantissa=0xC000 (-0.5), exponent=1  → wartość = -0.5 × 2^1 = -1.0
```

### Postać znormalizowana

Liczba jest **znormalizowana** gdy |mantysa| ≥ 0.5, czyli gdy bit14 (pierwszy bit po kropce) różni się od bitu znaku (bit15):

```
Znormalizowana (|m| ≥ 0.5):
  0.1xxxxx... → bit15=0, bit14=1 ✓
  1.0xxxxx... → bit15=1, bit14=0 ✓

NIEznormalizowana (|m| < 0.5):
  0.0xxxxx... → bit15=0, bit14=0 ✗ → przesuń lewo, exponent--
  1.1xxxxx... → bit15=1, bit14=1 ✗ → przesuń lewo, exponent--
```

Warunek nienormalizowana: `bit15 = bit14` (dwa najstarsze bity takie same).

Normalizacja zachowuje wartość liczby: przesunięcie mantysy ×2 kompensowane jest zmniejszeniem wykładnika o 1.

---

## 4. Architektura projektu

### Struktura plików

```
src/
├── fp_pkg.vhd        Pakiet: typ fp_t, stałe operacji
├── fp_normalize.vhd  Moduł kombinacyjny: normalizuje mantysę
├── fp_add_sub.vhd    Moduł sekwencyjny: dodawanie i odejmowanie (FSM 4-stanowy)
├── fp_mul.vhd        Moduł sekwencyjny: mnożenie (FSM 3-stanowy)
├── top.vhd           Top-level: łączy wszystko, podłącza do pinów płytki
└── tb_top.vhd        Testbench: tylko do symulacji, steruje top jak "wirtualna płytka"
```

### Diagram zależności

```
fp_pkg
  ↓ (używany przez wszystkich)
fp_normalize ← fp_add_sub
             ← fp_mul
                  ↓
fp_normalize ← fp_mul
                  ↓
             top
              ↑
           tb_top (tylko symulacja)
```

Kolejność kompilacji musi być od dołu grafu w górę: `fp_pkg` → `fp_normalize` → `fp_add_sub` → `fp_mul` → `top` → `tb_top`.

### Schemat blokowy top.vhd

```
KEY[0] ──NOT──→ reset ──────────────────────────┐
KEY[1] ──NOT──→ start ──────────┬───────────────┤
SW[0]  ─────→ add_sub_op        │               │
                                ▼               ▼
A_IN ──────────────────→ [fp_add_sub] ──→ add_sub_result ──┐
B_IN ──────────────────→                                    │
                                                            ├──→ MUX ──→ LEDR (mantysa)
A_IN ──────────────────→ [fp_mul]     ──→ mul_result    ──┤         └──→ LEDG (wykładnik [8:0])
B_IN ──────────────────→                             ↑    │
                                              SW[1:0]="10" └──────────────────────────────────┘
```

Oba moduły obliczeniowe działają **równolegle** — oba startują jednocześnie gdy `start=1`. Multiplekser na końcu wybiera który wynik pokazać na LED.

---

## 5. Algorytmy

### Dodawanie i odejmowanie

**Problem**: nie można po prostu dodać mantysy, bo mogą mieć różne wykładniki.

Przykład: `1.0 + 0.5`
```
A = 0.5 × 2^1 = 1.0
B = 0.5 × 2^0 = 0.5

Nie można: 0.5 + 0.5 = 1.0 (zły wynik)

Wyrównanie: doprowadź B do wykładnika A (eA=1):
  B' = 0.5 × 2^0 = (0.5/2) × 2^1 = 0.25 × 2^1

Teraz: (0.5 + 0.25) × 2^1 = 0.75 × 2^1 = 1.5 ✓
```

**Kroki algorytmu**:

1. **ALIGN** — wyrównaj wykładniki:
   - Oblicz różnicę `d = eA - eB`
   - Jeśli `d > 0`: mantysa B za mała → przesuń `mB` w prawo o `d` bitów, użyj `eA` jako wspólnego wykładnika
   - Jeśli `d < 0`: mantysa A za mała → przesuń `mA` w prawo o `|d|` bitów, użyj `eB`
   - Przesunięcie w prawo = dzielenie przez 2^d (utrata precyzji, ale wartość wykładnika wyrównana)

2. **COMPUTE** — dodaj lub odejmij wyrównane mantysy:
   - Wynik może wyjść poza zakres [-1, +1) → overflow
   - Obsługa overflow: przesuń wynik w prawo o 1, zwiększ wykładnik o 1

3. **NORMALIZE** — przywróć postać znormalizowaną:
   - Jeśli `|wynik| < 0.5`: przesuń w lewo, zmniejsz wykładnik (max 15 razy)

### Mnożenie

Matematycznie:
```
(mA × 2^eA) × (mB × 2^eB) = (mA × mB) × 2^(eA + eB)
```

**Kroki**:

1. **COMPUTE** — pomnóż mantysy i zsumuj wykładniki:
   - `mA × mB` = wynik 32-bitowy (16-bit × 16-bit)
   - Które 16 bitów wziąć? Patrz niżej.
   - `e_wynik = eA + eB`

2. **NORMALIZE** — tak samo jak w dodawaniu

**Dlaczego bity [30:15] z 32-bitowego iloczynu?**

Mantysa to liczba ułamkowa: `wartość = integer × 2^(-15)`

Więc:
```
mA_wartość = mA_int × 2^(-15)
mB_wartość = mB_int × 2^(-15)
iloczyn = mA_int × mB_int × 2^(-30)
```

Chcemy nową mantysę: `new_m_int × 2^(-15) = iloczyn`

Stąd: `new_m_int = mA_int × mB_int × 2^(-15) = product_32bit >> 15 = product[30:15]`

Przykład weryfikacyjny:
```
mA = 0x4000 = 16384  →  wartość = 0.5
mB = 0x4000 = 16384  →  wartość = 0.5

product = 16384 × 16384 = 268,435,456 = 0x10000000

product[30:15]:
  0x10000000 = 0001 0000 0000 0000 0000 0000 0000 0000
  bity 30..15 = 0010 0000 0000 0000 = 0x2000 = 8192
  wartość = 8192 × 2^(-15) = 0.25

e_wynik = eA + eB = 1 + 0 = 1
wynik = 0.25 × 2^1 = 0.5 = 1.0 × 0.5  ✓

(Normalizacja: 0.25 < 0.5 → przesuń lewo → 0x4000 = 0.5, exponent=0)
```

### Normalizacja

Warunek pętli: `bit15 == bit14` (liczba nienormalizowana).

```
Każda iteracja:
  Przesuń mantysę w lewo o 1 (mnożenie przez 2)
  Zmniejsz wykładnik o 1 (kompensacja)

Implementacja jako pętla for w procesie kombinacyjnym:
  for i in 0 to 14 loop
      if m(15) = m(14) then
          m := shift_left(m, 1);
          e := e - 1;
      end if;
  end loop;
```

Pętla `for` w procesie kombinacyjnym w VHDL **nie jest wykonywana w czasie** — syntezator rozwijaja ją w 15 poziomów logiki kombinacyjnej (multipleksery). Wynik jest gotowy kombinacyjnie, bez cykli zegara.

Moduł `fp_normalize` jest **kombinacyjny** — podłączony do wyjść rejestrów `fp_add_sub` i `fp_mul`. Kiedy rejestry zmieniają się na zboczu zegara, wynik normalizacji jest gotowy zanim nadejdzie następne zbocze.

---

## 6. Automat stanów (FSM)

### Czym jest FSM

FSM (Finite State Machine / Automat Stanów Skończonych) to układ który:
- Pamięta aktualny **stan** (w rejestrze)
- Na każdym zboczu zegara **przechodzi** do nowego stanu (zależnie od aktualnego stanu i wejść)
- W każdym stanie wykonuje określone **akcje** (obliczenia, przypisania)

W VHDL stan definiujemy jako typ wyliczeniowy (enum), a przejścia jako `case` wewnątrz synchronicznego procesu.

### FSM w fp_add_sub (4 stany)

```
         start=1
S_IDLE ──────────→ S_ALIGN ──→ S_COMPUTE ──→ S_NORMALIZE ──→ S_IDLE
  ↑                                                done=1        |
  └─────────────────────────────────────────────────────────────┘
```

| Stan | Czas trwania | Co się dzieje |
|---|---|---|
| S_IDLE | dowolnie długo | Czeka na `start=1`. Gdy nadejdzie: zatrzaskuje wejścia A, B |
| S_ALIGN | 1 cykl zegara | Liczy różnicę wykładników, przesuwa mniejszą mantysę |
| S_COMPUTE | 1 cykl zegara | Dodaje/odejmuje mantysy, obsługuje overflow |
| S_NORMALIZE | 1 cykl zegara | Odczytuje wynik z kombinacyjnego normalizatora, ustawia done=1 |

Wynik jest gotowy **4 cykle zegara** po `start=1`.

### FSM w fp_mul (3 stany)

```
         start=1
S_IDLE ──────────→ S_COMPUTE ──→ S_NORMALIZE ──→ S_IDLE
  ↑                                   done=1         |
  └──────────────────────────────────────────────────┘
```

Wynik gotowy **3 cykle** po `start=1`. Prostsze bo nie ma etapu wyrównywania.

### Implementacja FSM w VHDL

```vhdl
-- 1. Zdefiniuj typ wyliczeniowy dla stanów
type state_t is (S_IDLE, S_ALIGN, S_COMPUTE, S_NORMALIZE);
signal state : state_t := S_IDLE;

-- 2. W synchronicznym procesie: case na bieżącym stanie
process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            state <= S_IDLE;    -- reset: wróć do stanu początkowego
        else
            case state is
                when S_IDLE =>
                    if start = '1' then
                        state <= S_ALIGN;   -- przejście
                    end if;
                when S_ALIGN =>
                    -- ... obliczenia ...
                    state <= S_COMPUTE;
                -- itd.
            end case;
        end if;
    end if;
end process;
```

**Dlaczego FSM a nie zwykła logika?**

Dodawanie wymaga kilku kroków (wyrównaj → dodaj → normalizuj) i każdy krok potrzebuje wyników poprzedniego. Każdy krok zajmuje 1 cykl zegara. FSM "pamięta" w którym kroku jesteśmy i co mamy zrobić następnie.

---

## 7. Symulacja w ModelSim

### Przygotowanie projektu

1. Otwórz ModelSim (Altera Edition, dołączony do Quartus)
2. `File → New → Project`
3. Podaj nazwę projektu i lokalizację
4. `Add Existing File` → dodaj wszystkie `.vhd` z folderu `src/`

### Kolejność kompilacji (WAŻNE!)

Pliki muszą być kompilowane w takiej kolejności — moduł musi być skompilowany przed modułem który go używa:

```
1. fp_pkg.vhd
2. fp_normalize.vhd
3. fp_add_sub.vhd
4. fp_mul.vhd
5. top.vhd
6. tb_top.vhd
```

Aby skompilować: prawy klik na plik → `Compile` → `Compile Selected`, lub `Compile → Compile All` (ModelSim zazwyczaj sam rozpoznaje kolejność).

### Uruchomienie symulacji

1. `Simulate → Start Simulation`
2. Rozwiń `work` w drzewie bibliotek
3. Wybierz `tb_top` (testbench, nie `top`!)
4. Kliknij OK

### Dodawanie sygnałów do waveform

W oknie `sim` (hierarchia) kliknij na `tb_top` lub `dut` (instancja top w testbenchu). W oknie `Objects` pojawią się wszystkie sygnały. Zaznacz interesujące i przeciągnij do okna `Wave`, lub prawy klik → `Add to Wave`.

Najważniejsze sygnały do obserwacji:
- `clk` — zegar
- `key` — przyciski
- `sw` — przełączniki
- `ledr` — wynik (mantysa)
- `ledg` — wynik (wykładnik, bity [8:0])
- Sygnały wewnętrzne przez `dut/add_sub_inst/state` — stan FSM
- `dut/add_sub_inst/done` — flaga gotowości
- `dut/add_sub_inst/reg_result` — wynik add/sub (cały record)

### Uruchomienie

- `Run → Run All` — uruchamia do napotkania `wait;` (koniec testbenchu)
- Lub wpisz w konsoli: `run 2000 ns`

### Czytanie waveformów

Oś X = czas w nanosekundach. Każde 20 ns to jeden cykl zegara (50 MHz).

Przykładowy przebieg testu ADD:
```
czas    0      20     40     60     80    100    120    140    160
clk:   _|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_|¯|_
key:   1110...(reset)...1111......1101..1111...............
sw:    00 (ADD)
ledr:  0000.......................0000...6000............
                                              ↑
                                        wynik gotowy: 0x6000 = 1.5 (mantysa=0.75)
```

### Interpreting assert messages

W konsoli ModelSim zobaczysz linie jak:
```
# ** Note: TEST 1 PASS: ADD 1.0+0.5 = mantissa=0x6000 (=0.75)
```
lub przy błędzie:
```
# ** Error: TEST 1 FAIL: ADD 1.0+0.5, oczekiwano mantissa=0x6000, dostano 0x...
```

---

## 8. Wgrywanie na płytkę

### Wymagania

- Zainstalowany Quartus II (dla Cyclone II) lub Quartus Prime Lite
- Płytka DE1 lub podobna z Cyclone II
- Kabel USB-Blaster (zazwyczaj wbudowany w płytkę)

### Kroki w Quartus

1. `File → New Project Wizard`
2. Wybierz device: `Cyclone II EP2C20F484C7` (lub odpowiedni dla twojej płytki)
3. Dodaj wszystkie pliki `.vhd` z folderu `src/` **poza** `tb_top.vhd` (testbench nie jest do syntezy)
4. Ustaw `top` jako top-level entity: `Project → Set as Top-Level Entity`
5. `Processing → Start Compilation` — kompilacja może trwać kilka minut

### Przypisanie pinów

Przed wgraniem musisz przypisać porty encji `top` do fizycznych pinów płytki. W Quartus: `Assignments → Pin Planner`.

Typowe przypisania dla DE1:
```
CLOCK_50  → PIN_L1
KEY[0]    → PIN_R22
KEY[1]    → PIN_R21
SW[0]     → PIN_L22
SW[1]     → PIN_L21
LEDR[0]   → PIN_R17
LEDR[1]   → PIN_R16
... itd.
LEDG[0]   → PIN_U22
LEDG[1]   → PIN_U21
... itd.
```
(Dokładne numery pinów znajdziesz w dokumentacji swojej płytki — plik `.qsf` z przykładowych projektów DE1)

### Wgranie na płytkę

1. `Tools → Programmer`
2. `Add File` → wybierz wygenerowany plik `.sof` z folderu `output_files`
3. Kliknij `Start`

### Testowanie na płytce

Przełączniki i przyciski:
- `KEY[0]` (wciśnij) = reset
- `KEY[1]` (wciśnij jednokrotnie) = start obliczeń
- `SW[1:0]` = wybór operacji: `00`=ADD, `01`=SUB, `10`=MUL

Wynik wyświetlany binarnie: mantysa na `LEDR[15:0]`, dolne 9 bitów wykładnika na `LEDG[8:0]`.

Zmianę testowanych liczb A i B wykonujesz przez edycję stałych `A_IN` i `B_IN` w pliku `top.vhd` i ponowną kompilację.

---

## 9. Oczekiwane wyniki

### Wartości testowe

```
A = mantissa=0x4000 (+0.5), exponent=1  →  wartość = 0.5 × 2^1 = 1.0
B = mantissa=0x4000 (+0.5), exponent=0  →  wartość = 0.5 × 2^0 = 0.5
```

### Oczekiwane wyniki operacji

| Operacja | SW[1:0] | Wynik matematyczny | Mantysa (hex) | Wykładnik |
|---|---|---|---|---|
| ADD | `00` | 1.0 + 0.5 = **1.5** | `0x6000` (+0.75) | 1 |
| SUB | `01` | 1.0 − 0.5 = **0.5** | `0x4000` (+0.5) | 0 |
| MUL | `10` | 1.0 × 0.5 = **0.5** | `0x4000` (+0.5) | 0 |

### Weryfikacja ręczna ADD

```
A: m=0x4000 (+0.5), e=1
B: m=0x4000 (+0.5), e=0

ALIGN: d = eA - eB = 1 > 0  →  przesuń mB w prawo o 1
  mA' = 0x4000 (+0.5),  e_wspólne = 1
  mB' = 0x4000 >> 1 = 0x2000 (+0.25)

COMPUTE (ADD): 0x4000 + 0x2000 = 0x6000 (+0.75)
  bit16=0, bit15=0  →  brak overflow
  mantysa = 0x6000, exponent = 1

NORMALIZE: bit15=0, bit14=1  →  już znormalizowana
Wynik: mantissa=0x6000, exponent=1  →  0.75 × 2^1 = 1.5 ✓
```

### Weryfikacja ręczna MUL

```
A: m=0x4000 (int=16384), e=1
B: m=0x4000 (int=16384), e=0

COMPUTE:
  product = 16384 × 16384 = 268,435,456 = 0x10000000
  product[30:15] = 0x2000 (int=8192)  →  wartość = 8192 × 2^(-15) = 0.25
  e_wynik = 1 + 0 = 1
  mantysa = 0x2000, exponent = 1  →  wartość = 0.25 × 2^1 = 0.5

NORMALIZE: bit15=0, bit14=0  →  nienormalizowana (0.25 < 0.5)
  Iteracja 1: przesuń lewo: 0x4000, e = 0
  bit15=0, bit14=1  →  znormalizowana, stop

Wynik: mantissa=0x4000, exponent=0  →  0.5 × 2^0 = 0.5 ✓
```

---

## Słowniczek

| Termin | Znaczenie |
|---|---|
| FPGA | Programowalny układ scalony — "matryca" bloków logicznych |
| VHDL | Język opisu sprzętu (Hardware Description Language) |
| Entity | Interfejs modułu (porty wejść/wyjść) |
| Architecture | Implementacja modułu |
| Signal | Fizyczny drat lub rejestr; przypisanie `<=` działa po zakończeniu procesu |
| Variable | Lokalna wartość robocza; przypisanie `:=` natychmiastowe |
| Process | Blok kodu sekwencyjnego; budzi się gdy zmieni się coś z listy czułości |
| Port map | Instancjonowanie modułu — jak wstawienie układu scalonego |
| FSM | Automat Stanów — układ pamiętający stan i przechodzący między stanami |
| U2 | Kod uzupełnienia do dwóch — standard kodowania liczb całkowitych ze znakiem |
| Mantysa | Część ułamkowa liczby zmiennoprzecinkowej |
| Wykładnik | Potęga dwójki skalująca mantysę |
| Normalizacja | Dostosowanie mantysy do zakresu [-1, +1) przy zachowaniu wartości |
| Testbench | Plik VHDL tylko do symulacji — steruje modułem jak wirtualna płytka |
| ModelSim | Symulator VHDL — pokazuje przebiegi sygnałów w czasie (waveformy) |
| Quartus | Środowisko Altera/Intel do syntezy i wgrywania na FPGA |
| Active-low | Sygnał aktywny przy stanie logicznym '0' (np. wciśnięty przycisk = '0') |
