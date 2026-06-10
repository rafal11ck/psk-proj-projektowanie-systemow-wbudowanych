-- Prosty monitor do schematu BDF.
-- SW[3:2] wybiera, ktora mantysa jest pokazywana na czerwonych LED-ach.

library ieee;
use ieee.std_logic_1164.all;

entity led_monitor_bdf is
    port (
        sel             : in  std_logic_vector(1 downto 0);
        a_mantissa      : in  std_logic_vector(15 downto 0);
        b_mantissa      : in  std_logic_vector(15 downto 0);
        result_mantissa : in  std_logic_vector(15 downto 0);
        result_exponent : in  std_logic_vector(15 downto 0);
        ledr            : out std_logic_vector(15 downto 0);
        ledg            : out std_logic_vector(8 downto 0)
    );
end entity;

architecture rtl of led_monitor_bdf is
begin
    with sel select
        ledr <= result_mantissa when "00",
                a_mantissa      when "01",
                b_mantissa      when "10",
                result_mantissa when others;

    ledg <= result_exponent(8 downto 0);
end architecture;
