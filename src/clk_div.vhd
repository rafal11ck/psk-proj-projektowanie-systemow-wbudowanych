library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity clk_div is
    generic (
        TICKS_PER_SECOND : positive := 4
    );
    port (
        clk   : in  std_logic;
        reset : in  std_logic;
        tick  : out std_logic
    );
end entity;

architecture rtl of clk_div is
    constant CLOCK_HZ : positive := 50_000_000;

    function calculate_cycles(ticks_hz : positive) return positive is
    begin
        if ticks_hz >= CLOCK_HZ then
            return 1;
        end if;
        return CLOCK_HZ / ticks_hz;
    end function;

    constant CYCLES_PER_TICK : positive := calculate_cycles(TICKS_PER_SECOND);
    signal cnt : natural range 0 to CYCLES_PER_TICK - 1 := 0;
begin

    assert TICKS_PER_SECOND <= CLOCK_HZ
        report "clk_div TICKS_PER_SECOND cannot exceed CLOCK_HZ"
        severity failure;

    process(clk, reset)
    begin
        if reset = '1' then
            cnt  <= 0;
            tick <= '0';
        elsif rising_edge(clk) then
            if cnt = CYCLES_PER_TICK - 1 then
                cnt  <= 0;
                tick <= '1';
            else
                cnt  <= cnt + 1;
                tick <= '0';
            end if;
        end if;
    end process;

end architecture;
