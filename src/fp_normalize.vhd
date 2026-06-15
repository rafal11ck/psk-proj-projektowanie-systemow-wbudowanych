library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity fp_normalize is
    port (
        fp_in  : in  fp_t;
        fp_out : out fp_t
    );
end entity;

architecture rtl of fp_normalize is
begin
    process(fp_in)
        variable m : signed(15 downto 0);
        variable e : signed(15 downto 0);
    begin
        m := fp_in.mantissa;
        e := fp_in.exponent;

        if m /= to_signed(0, 16) then
            for i in 0 to 14 loop
                if m(15) = m(14) then
                    m := shift_left(m, 1);
                    e := e - 1;
                end if;
            end loop;
        end if;

        fp_out.mantissa <= m;
        fp_out.exponent <= e;
    end process;
end architecture;
