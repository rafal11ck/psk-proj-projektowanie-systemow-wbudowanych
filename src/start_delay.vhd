-- Opoznia impuls tick o jeden cykl zegara.
-- Liczniki aktualizuja A/B na ticku, a ALU dostaje start w kolejnym cyklu,
-- dlatego wynik odpowiada wartosciom aktualnie widocznym na wyjsciach licznikow.

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
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                start <= '0';
            else
                start <= tick;
            end if;
        end if;
    end process;
end architecture;
