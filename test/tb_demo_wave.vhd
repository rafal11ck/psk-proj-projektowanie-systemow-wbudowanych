-- Czysta symulacja demonstracyjna: dwa generatory, ALU i kolejno ADD/SUB/MUL.

library ieee;
use ieee.std_logic_1164.all;

entity tb_demo_wave is
end entity;

architecture sim of tb_demo_wave is
    signal clk  : std_logic := '0';
    signal sw   : std_logic_vector(15 downto 0) := (others => '0');
    signal key  : std_logic_vector(3 downto 0) := "1110";
    signal ledr : std_logic_vector(15 downto 0);
    signal ledg : std_logic_vector(8 downto 0);
begin
    dut : entity work.top
        generic map (
            CLK_DIV_MAX => 6
        )
        port map (
            CLOCK_50 => clk,
            SW       => sw,
            KEY      => key,
            LEDR     => ledr,
            LEDG     => ledg
        );

    clk <= not clk after 10 ns;

    stimulus : process
    begin
        wait for 60 ns;
        key(0) <= '1';

        sw(1 downto 0) <= "00";  -- ADD
        wait for 3500 ns;

        sw(1 downto 0) <= "01";  -- SUB
        wait for 3500 ns;

        sw(1 downto 0) <= "10";  -- MUL
        wait;
    end process;
end architecture;
