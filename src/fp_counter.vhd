library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity fp_counter is
    generic (
        WIDTH : natural := 4
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        en    : in  std_logic;
        value : out fp_t;
        carry : out std_logic
    );
end entity;

architecture rtl of fp_counter is
    signal cnt : signed(WIDTH-1 downto 0) := (others => '0');
begin

    assert WIDTH >= 2 and WIDTH <= 16
        report "fp_counter WIDTH must be in range 2..16"
        severity failure;

    process(clk, reset)
    begin
        if reset = '1' then
            cnt <= (others => '0');
        elsif rising_edge(clk) then
            if en = '1' then
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    carry <= '1' when (en = '1' and cnt = to_signed(-1, WIDTH)) else '0';

    value.mantissa <= shift_left(resize(cnt, 16), 16 - WIDTH);
    value.exponent <= (others => '0');

end architecture;
