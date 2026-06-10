-- Dzielnik zegara: zamienia szybki zegar plytki (50 MHz) na powolny impuls 'tick'.
-- Bez tego liczniki tykalyby 50 milionow razy na sekunde i na diodach nie dalo by sie
-- nic odczytac. 'tick' jest wysoki przez DOKLADNIE jeden cykl zegara co (DIV_MAX+1) cykli.
--
-- DIV_MAX jest generic (parametr): synteza uzywa wartosci domyslnej (~4 Hz),
-- a testbench nadpisuje ja mala liczba, zeby symulacja byla szybka.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_div is
    generic (
        -- tick co (DIV_MAX+1) cykli. 12_500_000 @ 50 MHz => okres 0.25 s => ~4 Hz.
        DIV_MAX : natural := 12_500_000
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;   -- synchroniczny, active high
        tick  : out std_logic    -- impuls 1-cyklowy
    );
end entity;

architecture rtl of clk_div is
    -- "natural range 0 to DIV_MAX": syntezator dobierze minimalna liczbe bitow licznika.
    signal cnt : natural range 0 to DIV_MAX := 0;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt  <= 0;
                tick <= '0';
            elsif cnt = DIV_MAX then
                -- Osiagnieto koniec okresu: wystaw impuls i zacznij liczyc od nowa.
                cnt  <= 0;
                tick <= '1';
            else
                cnt  <= cnt + 1;
                tick <= '0';
            end if;
        end if;
    end process;

end architecture;
