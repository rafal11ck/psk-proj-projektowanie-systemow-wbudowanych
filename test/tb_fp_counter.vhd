-- Test sekwencji generatorow A/B uzywanej do demonstracji ALU.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity tb_fp_counter is
end entity;

architecture sim of tb_fp_counter is
    signal clk     : std_logic := '0';
    signal reset   : std_logic := '1';
    signal en      : std_logic := '0';
    signal carry_a : std_logic;
    signal value_a : fp_t;
    signal value_b : fp_t;

    type sample_array_t is array (1 to 16) of std_logic_vector(15 downto 0);
    constant EXPECTED_A : sample_array_t := (
        x"1000", x"2000", x"3000", x"4000",
        x"5000", x"6000", x"7000", x"8000",
        x"9000", x"A000", x"B000", x"C000",
        x"D000", x"E000", x"F000", x"0000"
    );
begin
    counter_a : entity work.fp_counter
        port map (
            clk   => clk,
            reset => reset,
            en    => en,
            value => value_a,
            carry => carry_a
        );

    counter_b : entity work.fp_counter
        port map (
            clk   => clk,
            reset => reset,
            en    => carry_a,
            value => value_b,
            carry => open
        );

    clk <= not clk after 10 ns;

    stimulus : process
    begin
        wait until rising_edge(clk);
        wait until rising_edge(clk);
        reset <= '0';
        en    <= '1';

        for i in EXPECTED_A'range loop
            wait until rising_edge(clk);
            wait for 1 ns;

            assert std_logic_vector(value_a.mantissa) = EXPECTED_A(i)
                report "Unexpected A sample at step " & integer'image(i)
                severity error;

            assert value_a.exponent = to_signed(0, 16)
                report "A exponent must remain zero"
                severity error;

            if i = 15 then
                assert carry_a = '1'
                    report "A carry must announce the full-cycle wrap"
                    severity error;
            elsif i = 16 then
                assert std_logic_vector(value_b.mantissa) = x"1000"
                    report "B must advance once after a full A cycle"
                    severity error;
            else
                assert std_logic_vector(value_b.mantissa) = x"0000"
                    report "B advanced before A completed its cycle"
                    severity error;
            end if;
        end loop;

        report "tb_fp_counter PASS: signed sawtooth and A/B odometer verified"
            severity note;
        wait;
    end process;
end architecture;
