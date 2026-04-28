-- Pakiet wspolnych typow i stalych. Importowany przez: use work.fp_pkg.all;
-- Teoria formatu zmiennoprzecinkowego: patrz README.md, rozdzial 3.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fp_pkg is

    -- Typ reprezentujacy jedna liczbe zmiennoprzecinkowa.
    -- Wartosc liczby = mantissa * 2^exponent
    -- mantissa: signed U2, wyobrazana kropka za bitem znaku -> zakres [-1, +1)
    -- exponent: signed U2, zwykla liczba calkowita -> zakres [-32768, +32767]
    type fp_t is record
        mantissa : signed(15 downto 0);
        exponent : signed(15 downto 0);
    end record;

    -- Zero zmiennoprzecinkowe. (others => '0') ustawia wszystkie bity rekordu na 0.
    constant FP_ZERO : fp_t := (
        mantissa => (others => '0'),
        exponent => (others => '0')
    );

    -- Kody operacji dla wejscia op w top.vhd
    constant OP_ADD : std_logic_vector(1 downto 0) := "00";
    constant OP_SUB : std_logic_vector(1 downto 0) := "01";
    constant OP_MUL : std_logic_vector(1 downto 0) := "10";

end package;
