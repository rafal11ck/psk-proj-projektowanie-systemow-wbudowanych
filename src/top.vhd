-- Top-level: laczy wszystkie moduly i podlacza do pinow plytki.
-- Schemat blokowy i opis pinow: README.md rozdzial 4 i 8.
--
-- Testowane wartosci (zmien A_IN/B_IN zeby testowac inne przypadki):
--   A = 1.0  (mantissa=0x4000=+0.5, exponent=1  ->  0.5 * 2^1 = 1.0)
--   B = 0.5  (mantissa=0x4000=+0.5, exponent=0  ->  0.5 * 2^0 = 0.5)
-- Oczekiwane wyniki: ADD->0x6000/e=1, SUB->0x4000/e=0, MUL->0x4000/e=0

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity top is
    port (
        CLOCK_50 : in  std_logic;
        SW       : in  std_logic_vector(15 downto 0);  -- SW[1:0] = operacja
        KEY      : in  std_logic_vector(3  downto 0);  -- active-low: wcisniety='0'
        LEDR     : out std_logic_vector(15 downto 0)   -- mantysa wyniku na diodach
    );
end entity;

architecture rtl of top is

    -- constant zamiast signal: wartosc nigdy sie nie zmienia po syntezie.
    -- to_signed(16#4000#, 16): konwertuj hex 0x4000 na signed 16-bitowy.
    -- 16#...# to notacja VHDL dla hex (odpowiednik 0x... w C).
    constant A_IN : fp_t := (
        mantissa => to_signed(16#4000#, 16),
        exponent => to_signed(1, 16)
    );
    constant B_IN : fp_t := (
        mantissa => to_signed(16#4000#, 16),
        exponent => to_signed(0, 16)
    );

    signal reset_sig  : std_logic;
    signal start_sig  : std_logic;
    signal add_sub_op : std_logic;

    signal add_sub_result : fp_t;
    signal mul_result     : fp_t;
    signal add_sub_done   : std_logic;
    signal mul_done       : std_logic;

begin

    -- Przyciski KEY sa active-low (wcisniety = '0').
    -- "not KEY(0)" odwraca logike: wcisniety -> reset_sig='1' (active high dla naszych modulow).
    reset_sig  <= not KEY(0);
    start_sig  <= not KEY(1);
    add_sub_op <= SW(0);  -- bit0: 0=ADD, 1=SUB (irrelevant gdy SW[1]='1' = MUL)

    -- Instancje modulow. Oba dostaja te same wejscia i dzialaja rownoleglie.
    -- Multiplekser na koncu wybiera ktory wynik pokazac.
    add_sub_inst : entity work.fp_add_sub
        port map (
            clk    => CLOCK_50,
            reset  => reset_sig,
            start  => start_sig,
            op     => add_sub_op,
            a      => A_IN,
            b      => B_IN,
            result => add_sub_result,
            done   => add_sub_done
        );

    mul_inst : entity work.fp_mul
        port map (
            clk    => CLOCK_50,
            reset  => reset_sig,
            start  => start_sig,
            a      => A_IN,
            b      => B_IN,
            result => mul_result,
            done   => mul_done
        );

    -- "with ... select": kombinacyjny multiplekser (odpowiednik switch/case poza procesem).
    -- std_logic_vector(x): konwertuje signed x na std_logic_vector -- tylko reinterpretacja bitow.
    -- OP_MUL zdefiniowane w fp_pkg jako "10"; "when others" lapie ADD i SUB.
    with SW(1 downto 0) select
        LEDR <= std_logic_vector(mul_result.mantissa)     when OP_MUL,
                std_logic_vector(add_sub_result.mantissa) when others;

end architecture;
