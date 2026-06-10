-- Jednostka arytmetyczna (ALU) -- WLASCIWY "uklad".
-- Ma jawne wejscia A i B (porty fp_t) oraz wybor operacji. Nie wie i nie dba o to,
-- skad pochodza liczby: moze go sterowac testbench albo liczniki w top.vhd
-- (podpiete z zewnatrz na porty a/b -- tak samo jak stimulus w testbenchu).
--
-- Wewnatrz: fp_add_sub i fp_mul licza rownolegle, multiplekser wybiera wynik wg op.
-- Schemat blokowy: README.md rozdzial 4.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity alu is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;                      -- synchroniczny, active high
        start  : in  std_logic;                      -- impuls startu (1 cykl)
        op     : in  std_logic_vector(1 downto 0);   -- 00=ADD, 01=SUB, 10=MUL
        a      : in  fp_t;                            -- wejscie A
        b      : in  fp_t;                            -- wejscie B
        result : out fp_t;                           -- wynik wybranej operacji
        done   : out std_logic                       -- high gdy wynik gotowy
    );
end entity;

architecture rtl of alu is

    signal add_sub_result : fp_t;
    signal mul_result     : fp_t;
    signal add_sub_done   : std_logic;
    signal mul_done       : std_logic;

begin

    -- Oba moduly dostaja te same wejscia i dzialaja rownoleglie.
    add_sub_inst : entity work.fp_add_sub
        port map (
            clk    => clk,
            reset  => reset,
            start  => start,
            op     => op(0),   -- bit0: 0=ADD, 1=SUB (irrelevant gdy wybrane MUL)
            a      => a,
            b      => b,
            result => add_sub_result,
            done   => add_sub_done
        );

    mul_inst : entity work.fp_mul
        port map (
            clk    => clk,
            reset  => reset,
            start  => start,
            a      => a,
            b      => b,
            result => mul_result,
            done   => mul_done
        );

    -- Multiplekser wyniku wg op. OP_MUL zdefiniowane w fp_pkg jako "10";
    -- "when others" lapie ADD ("00") i SUB ("01").
    with op select
        result <= mul_result     when OP_MUL,
                  add_sub_result when others;

    with op select
        done <= mul_done     when OP_MUL,
                add_sub_done when others;

end architecture;
