library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity alu is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        start  : in  std_logic;
        op     : in  std_logic_vector(1 downto 0);
        a      : in  fp_t;
        b      : in  fp_t;
        result : out fp_t;
        done   : out std_logic
    );
end entity;

architecture rtl of alu is

    signal add_sub_result : fp_t;
    signal mul_result     : fp_t;
    signal add_sub_done   : std_logic;
    signal mul_done       : std_logic;

begin

    add_sub_inst : entity work.fp_add_sub
        port map (
            clk    => clk,
            reset  => reset,
            start  => start,
            op     => op(0),
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

    with op select
        result <= mul_result     when OP_MUL,
                  add_sub_result when others;

    with op select
        done <= mul_done     when OP_MUL,
                add_sub_done when others;

end architecture;
