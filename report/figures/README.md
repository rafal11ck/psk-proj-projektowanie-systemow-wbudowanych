# Zrzuty ekranu do sprawozdania

Pliki graficzne należy umieścić w tym katalogu. Po ponownej kompilacji
`report/sprawozdanie.tex` ramki zastąpią się zrzutami automatycznie.

## Wymagane

- `quartus_blocks.png` - cały schemat `demo.bdf` w Quartusie; widoczne bloki,
  połączenia i nazwy portów. Zrzut jest umieszczany na stronie poziomej.
- `modelsim_waveforms.png` - okno Wave po `do ../../test/wave_scope.do`;
  mantysy A, B i wyniku najlepiej ustawić jako `Analog (Step)`. Ten zrzut
  również jest umieszczany na stronie poziomej.
- `modelsim_checker.png` - końcówka okna Transcript po
  `do ../../test/check_counter_results.do`, z podsumowaniem 248/248.

## Opcjonalne

- `quartus_compilation.png` - Compilation Report lub Messages pokazujące
  zakończenie kompilacji bez błędów.

Najlepiej użyć formatu PNG i przyciąć zrzuty tak, aby tekst pozostał czytelny.

## Kompilacja

Z katalogu `report` uruchomić dwukrotnie:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error sprawozdanie.tex
```

Wynikiem jest plik `report/sprawozdanie.pdf`.
