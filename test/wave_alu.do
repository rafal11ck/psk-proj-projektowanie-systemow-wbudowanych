view wave
delete wave *

add wave -divider "Sterowanie"
add wave sim:/tb_demo_wave/clk
add wave -radix binary sim:/tb_demo_wave/sw
add wave sim:/tb_demo_wave/dut/tick
add wave sim:/tb_demo_wave/dut/start_sig

add wave -divider "Wejscie A"
add wave -radix hexadecimal sim:/tb_demo_wave/dut/a_in/mantissa
add wave -radix decimal     sim:/tb_demo_wave/dut/a_in/mantissa
add wave -radix decimal     sim:/tb_demo_wave/dut/a_in/exponent

add wave -divider "Wejscie B"
add wave -radix hexadecimal sim:/tb_demo_wave/dut/b_in/mantissa
add wave -radix decimal     sim:/tb_demo_wave/dut/b_in/mantissa
add wave -radix decimal     sim:/tb_demo_wave/dut/b_in/exponent

add wave -divider "Wynik ALU"
add wave -radix hexadecimal sim:/tb_demo_wave/dut/alu_result/mantissa
add wave -radix decimal     sim:/tb_demo_wave/dut/alu_result/mantissa
add wave -radix decimal     sim:/tb_demo_wave/dut/alu_result/exponent
add wave sim:/tb_demo_wave/dut/alu_inst/done

configure wave -namecolwidth 300
configure wave -valuecolwidth 120
configure wave -timelineunits ns

run 11 us
wave zoom full
