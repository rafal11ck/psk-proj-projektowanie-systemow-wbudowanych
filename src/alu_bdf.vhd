library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity alu_bdf is
    port (
        clk             : in  std_logic;
        reset           : in  std_logic;
        start           : in  std_logic;
        op              : in  std_logic_vector(1 downto 0);
        a_mantissa      : in  std_logic_vector(15 downto 0);
        a_exponent      : in  std_logic_vector(15 downto 0);
        b_mantissa      : in  std_logic_vector(15 downto 0);
        b_exponent      : in  std_logic_vector(15 downto 0);
        result_mantissa : out std_logic_vector(15 downto 0);
        result_exponent : out std_logic_vector(15 downto 0);
        done            : out std_logic
    );
end entity;

architecture rtl of alu_bdf is
    signal a_fp      : fp_t;
    signal b_fp      : fp_t;
    signal result_fp : fp_t;
begin
    a_fp.mantissa <= signed(a_mantissa);
    a_fp.exponent <= signed(a_exponent);
    b_fp.mantissa <= signed(b_mantissa);
    b_fp.exponent <= signed(b_exponent);

    alu_inst : entity work.alu
        port map (
            clk    => clk,
            reset  => reset,
            start  => start,
            op     => op,
            a      => a_fp,
            b      => b_fp,
            result => result_fp,
            done   => done
        );

    result_mantissa <= std_logic_vector(result_fp.mantissa);
    result_exponent <= std_logic_vector(result_fp.exponent);
end architecture;
