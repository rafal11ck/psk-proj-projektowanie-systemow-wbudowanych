# Widok przebiegow aktualnego top-level demo.
# Skrypt uruchamia sie z katalogu simulation/qsim:
#   do ../../test/wave_scope.do

catch {quit -sim}

vlib work
vlog -work work fp_alu.vo

vsim -novopt -t 1ps \
    -L cycloneive_ver \
    -L altera_ver \
    -L altera_mf_ver \
    -L 220model_ver \
    -L sgate work.demo

# Zegar 50 MHz, reset przez pierwsze 200 ns oraz trzy kolejne operacje.
force -freeze sim:/demo/CLOCK 0 0, 1 10 ns -repeat 20 ns
force -freeze sim:/demo/RESET 1 0, 0 200 ns
force -freeze sim:/demo/OP 2#00 0, 2#01 15 us, 2#10 30 us

view wave
catch {delete wave *}

add wave -divider "STEROWANIE"
add wave -label "CLOCK" sim:/demo/CLOCK
add wave -label "RESET" sim:/demo/RESET
add wave -radix binary -label "OP: 00 ADD, 01 SUB, 10 MUL" sim:/demo/OP

add wave -divider "WEJSCIE A"
add wave -analog-step -height 110 -min -32768 -max 32767 -radix signed \
    -label "A - mantysa Q1.15" sim:/demo/A_MANTISSA
add wave -radix signed -label "A - wykladnik" sim:/demo/A_EXPONENT

add wave -divider "WEJSCIE B"
add wave -analog-step -height 110 -min -32768 -max 32767 -radix signed \
    -label "B - mantysa Q1.15" sim:/demo/B_MANTISSA
add wave -radix signed -label "B - wykladnik" sim:/demo/B_EXPONENT

add wave -divider "WYNIK ALU"
add wave -analog-step -height 140 -min -32768 -max 32767 -radix signed \
    -label "Wynik - mantysa Q1.15" sim:/demo/RESULT_MANTISA
add wave -radix signed -label "Wynik - wykladnik" sim:/demo/RESULT_EXPONENT
add wave -label "DONE" sim:/demo/DONE

configure wave -namecolwidth 240
configure wave -valuecolwidth 110
configure wave -timelineunits us

run 50 us
wave zoom full
