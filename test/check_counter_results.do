# Kontrola liczbowa aktualnego demo z generatorami A i B.
# Przy kazdym impulsie DONE skrypt odczytuje liczby fp_t, oblicza wartosc
# mantissa * 2^exponent i porownuje wynik ALU z dzialaniem matematycznym.
#
# Uruchamianie z katalogu simulation/qsim:
#   do ../../test/check_counter_results.do

catch {quit -sim}

vlib work
vlog -work work fp_alu.vo

vsim -novopt -t 1ps \
    -L cycloneive_ver \
    -L altera_ver \
    -L altera_mf_ver \
    -L 220model_ver \
    -L sgate work.demo

force -freeze sim:/demo/CLOCK 0 0, 1 10 ns -repeat 20 ns
force -freeze sim:/demo/RESET 1 0, 0 200 ns
force -freeze sim:/demo/OP 2#00 0, 2#01 15 us, 2#10 30 us

file mkdir ../../build
set check_log [open ../../build/counter_results.log w]
set check_count 0
set check_failures 0

proc fp_value {mantissa exponent} {
    return [expr {double($mantissa) * pow(2.0, $exponent) / 32768.0}]
}

proc check_counter_result {} {
    global check_log check_count check_failures

    set op [examine -radix unsigned sim:/demo/OP]
    set am [examine -radix signed sim:/demo/A_MANTISSA]
    set ae [examine -radix signed sim:/demo/A_EXPONENT]
    set bm [examine -radix signed sim:/demo/B_MANTISSA]
    set be [examine -radix signed sim:/demo/B_EXPONENT]
    set rm [examine -radix signed sim:/demo/RESULT_MANTISA]
    set re [examine -radix signed sim:/demo/RESULT_EXPONENT]

    set a [fp_value $am $ae]
    set b [fp_value $bm $be]
    set result [fp_value $rm $re]

    switch -- $op {
        0 {
            set op_name "ADD"
            set expected [expr {$a + $b}]
        }
        1 {
            set op_name "SUB"
            set expected [expr {$a - $b}]
        }
        2 {
            set op_name "MUL"
            set expected [expr {$a * $b}]
        }
        default {
            set op_name "UNKNOWN"
            set expected 0.0
        }
    }

    set error [expr {abs($result - $expected)}]
    if {$op <= 2 && $error < 1.0e-9} {
        set status "PASS"
    } else {
        set status "FAIL"
        incr check_failures
    }
    incr check_count

    set line [format \
        "%4d  %-3s  A=%8.5f  B=%8.5f  expected=%9.5f  ALU=%9.5f  m=%6d e=%3d  %s" \
        $check_count $op_name $a $b $expected $result $rm $re $status]

    puts $line
    puts $check_log $line
    flush $check_log
}

puts $check_log "sample op   inputs and expected value                 encoded ALU result"
puts $check_log "--------------------------------------------------------------------------------"

when -label CHECK_COUNTER_RESULTS {sim:/demo/DONE == 1} {
    check_counter_result
}

run 50 us

set summary [format \
    "SUMMARY: checked=%d passed=%d failed=%d" \
    $check_count [expr {$check_count - $check_failures}] $check_failures]
puts $summary
puts $check_log $summary
close $check_log

if {$check_failures == 0} {
    puts "COUNTER/ALU CHECK PASSED"
} else {
    puts "COUNTER/ALU CHECK FAILED"
}
