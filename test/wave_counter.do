view wave
delete wave *

add wave -divider "Sterowanie"
add wave sim:/tb_fp_counter/clk
add wave sim:/tb_fp_counter/reset
add wave sim:/tb_fp_counter/en

add wave -divider "Generator A"
add wave -radix hexadecimal sim:/tb_fp_counter/value_a/mantissa
add wave -radix decimal     sim:/tb_fp_counter/value_a/mantissa
add wave sim:/tb_fp_counter/carry_a

add wave -divider "Generator B"
add wave -radix hexadecimal sim:/tb_fp_counter/value_b/mantissa
add wave -radix decimal     sim:/tb_fp_counter/value_b/mantissa

configure wave -namecolwidth 260
configure wave -valuecolwidth 120
configure wave -timelineunits ns

run 400 ns
wave zoom full
