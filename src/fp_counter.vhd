-- Licznik generujacy liczbe zmiennoprzecinkowa (fp_t) na wejscie ALU.
-- Inkrementuje sie o 1 na kazdy impuls 'en' (czyli na kazdy tick z clk_div).
--
-- Mapowanie licznika na fp_t:
--   value = cnt / 2^(WIDTH-1)  (mantysa Q1.15, exponent = 0)
--   WIDTH=4 -> 0, 1/8, ... 7/8, -1, -7/8, ... -1/8, 0.
-- Po maksimum dodatnim kod U2 automatycznie przechodzi do -1, zgodnie z
-- przebiegiem pily omawianym podczas konsultacji.
--
-- 'carry' sygnalizuje pelny obieg (cnt z -1/8 na 0) -- uzywane w top.vhd,
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
    signal cnt : signed(WIDTH-1 downto 0) := (others => '0');
begin

    assert WIDTH >= 2 and WIDTH <= 16
        report "fp_counter WIDTH must be in range 2..16"
        severity failure;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                cnt <= (others => '0');
            elsif en = '1' then
                cnt <= cnt + 1;   -- U2: max dodatni -> min ujemny, -1 -> 0
            end if;
        end if;
    end process;

    -- Pelny obieg konczy sie przy przejsciu z kodu -1 na 0.
    carry <= '1' when (en = '1' and cnt = to_signed(-1, WIDTH)) else '0';

    -- Mantysa Q1.15: zachowujemy znak i wsuwamy kod WIDTH-bitowy w najstarsze
    -- bity. Dla WIDTH=4 krok wynosi 1/8, a 1000 oznacza dokladnie -1.
    value.mantissa <= shift_left(resize(cnt, 16), 16 - WIDTH);
    value.exponent <= (others => '0');

end architecture;
