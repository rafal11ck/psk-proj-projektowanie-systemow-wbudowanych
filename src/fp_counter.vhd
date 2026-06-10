-- Licznik generujacy liczbe zmiennoprzecinkowa (fp_t) na wejscie ALU.
-- Inkrementuje sie o 1 na kazdy impuls 'en' (czyli na kazdy tick z clk_div).
--
-- Mapowanie licznika na fp_t:
--   value = cnt / 2^WIDTH  (mantysa Q1.15, exponent = 0)
--   WIDTH=4 -> cnt 0..15 -> wartosci 0, 0.0625, 0.125, ... 0.9375 (krok 1/16).
-- Licznik trzyma sie wiec w zakresie [0, 1) i kazda wartosc jest czytelna.
--
-- 'carry' sygnalizuje przewiniecie (cnt z maksimum na 0) -- uzywane w top.vhd,
-- zeby drugi licznik (B) tykal dopiero gdy pierwszy (A) zatoczy pelne kolo
-- (jak licznik kilometrow): z czasem przewijaja sie wszystkie kombinacje (A, B).

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity fp_counter is
    generic (
        WIDTH : natural := 4    -- licznik liczy 0 .. (2^WIDTH - 1)
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;   -- synchroniczny, active high
        en    : in  std_logic;   -- inkrementuj gdy '1' (impuls 1-cyklowy)
        value : out fp_t;        -- wygenerowana liczba
        carry : out std_logic    -- '1' w cyklu, gdy licznik wlasnie sie przewija
    );
end entity;

architecture rtl of fp_counter is
    signal cnt : unsigned(WIDTH-1 downto 0) := (others => '0');
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt <= (others => '0');
            elsif en = '1' then
                cnt <= cnt + 1;   -- przepelnienie zawija automatycznie do 0
            end if;
        end if;
    end process;

    -- Przewiniecie: licznik jest na maksimum i wlasnie go inkrementujemy.
    carry <= '1' when (en = '1' and cnt = (2**WIDTH - 1)) else '0';

    -- Mantysa Q1.15: wsuwamy licznik w gorne bity (shift_left o 15-WIDTH).
    -- resize(cnt, 16) rozszerza do 16 bitow (zerami), signed(...) reinterpretuje
    -- jako liczbe ze znakiem -- zawsze dodatnia, bo gorne bity sa zerowe.
    value.mantissa <= shift_left(signed(resize(cnt, 16)), 15 - WIDTH);
    value.exponent <= (others => '0');

end architecture;
