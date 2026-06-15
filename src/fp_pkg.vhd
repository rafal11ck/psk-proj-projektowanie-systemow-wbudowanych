library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package fp_pkg is

    type fp_t is record
        mantissa : signed(15 downto 0);
        exponent : signed(15 downto 0);
    end record;

    constant FP_ZERO : fp_t := (
        mantissa => (others => '0'),
        exponent => (others => '0')
    );

    constant OP_ADD : std_logic_vector(1 downto 0) := "00";
    constant OP_SUB : std_logic_vector(1 downto 0) := "01";
    constant OP_MUL : std_logic_vector(1 downto 0) := "10";

end package;
