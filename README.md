# ALU zmiennoprzecinkowe

Projekt w Quartus II przedstawia ALU wykonujace dodawanie, odejmowanie
i mnozenie liczb w prostym formacie zmiennoprzecinkowym:

```text
wartosc = mantysa_Q1.15 * 2^wykladnik
```

Top-level projektu stanowi schemat [demo.bdf](demo.bdf). Dwa liczniki generuja
wejscia A i B. Licznik A zmienia wartosc przy kazdym impulsie `tick`, a licznik
B po pelnym cyklu A. Pozwala to automatycznie przechodzic przez rozne pary
argumentow ALU.

## Interfejs

Wejscia:

- `CLOCK` - zegar 50 MHz,
- `RESET` - reset asynchroniczny, aktywny stanem wysokim,
- `OP[1..0]` - `00` ADD, `01` SUB, `10` MUL.

Wyjscia:

- `A_MANTISSA`, `A_EXPONENT`,
- `B_MANTISSA`, `B_EXPONENT`,
- `RESULT_MANTISA`, `RESULT_EXPONENT`,
- `DONE` - impuls informujacy o gotowym wyniku.

## Struktura

```text
demo.bdf
  clk_div -> fp_counter_bdf A -> alu_bdf
          -> fp_counter_bdf B -> alu_bdf
          -> start_delay      -> alu_bdf
```

Najwazniejsze pliki:

- `src/fp_pkg.vhd` - format liczby i kody operacji,
- `src/fp_counter.vhd` - generator przebiegu piloksztaltnego,
- `src/fp_add_sub.vhd` - dodawanie i odejmowanie,
- `src/fp_mul.vhd` - mnozenie,
- `src/fp_normalize.vhd` - normalizacja wyniku,
- `src/alu.vhd` - wybor wyniku operacji,
- `src/*_bdf.vhd` - wrappery magistral dla Block Editor,
- `test/wave_scope.do` - widok przebiegow w ModelSim,
- `test/check_counter_results.do` - automatyczna kontrola wynikow.

## Uruchomienie

1. Otworz `fp_alu.qpf` w Quartus II.
2. Uruchom `Processing -> Start Compilation`.
3. Wygenerowana netlista znajduje sie w `simulation/qsim/fp_alu.vo`.
4. Uruchom ModelSim z katalogu `simulation/qsim`.

Widok przebiegow:

```tcl
do ../../test/wave_scope.do
```

Kontrola liczbowa:

```tcl
do ../../test/check_counter_results.do
```

Checker zapisuje wynik do `build/counter_results.log`. Poprawna symulacja
konczy sie komunikatem:

```text
COUNTER/ALU CHECK PASSED
```

W schemacie parametr `TICKS_PER_SECOND` jest ustawiony na `5_000_000`,
co daje impuls `tick` co 10 cykli zegara i przyspiesza symulacje.

## Sprawozdanie

Pelny opis architektury, modulow, symulacji i testow znajduje sie w:

- `report/sprawozdanie.tex`,
- `report/sprawozdanie.pdf`.

Instrukcja dodawania zrzutow ekranu znajduje sie w
`report/figures/README.md`.
