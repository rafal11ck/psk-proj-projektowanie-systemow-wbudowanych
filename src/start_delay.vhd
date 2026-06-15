library ieee;
use ieee.std_logic_1164.all;

entity start_delay is
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        tick  : in  std_logic;
        start : out std_logic
    );
end entity;

architecture rtl of start_delay is
begin
    process(clk, reset)
    begin
        if reset = '1' then
            start <= '0';
        elsif rising_edge(clk) then
            start <= tick;
        end if;
    end process;
end architecture;
