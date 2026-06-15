library ieee;
use ieee.std_logic_1164.all;
use work.fp_pkg.all;

entity fp_counter_bdf is
    port (
        clk            : in  std_logic;
        reset          : in  std_logic;
        en             : in  std_logic;
        value_mantissa : out std_logic_vector(15 downto 0);
        value_exponent : out std_logic_vector(15 downto 0);
        carry          : out std_logic
    );
end entity;

architecture rtl of fp_counter_bdf is
    signal value_fp : fp_t;
begin
    counter_inst : entity work.fp_counter
        generic map (
            WIDTH => 4
        )
        port map (
            clk   => clk,
            reset => reset,
            en    => en,
            value => value_fp,
            carry => carry
        );

    value_mantissa <= std_logic_vector(value_fp.mantissa);
    value_exponent <= std_logic_vector(value_fp.exponent);
end architecture;
