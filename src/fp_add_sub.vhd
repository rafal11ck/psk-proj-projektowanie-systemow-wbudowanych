library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity fp_add_sub is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        start  : in  std_logic;
        op     : in  std_logic;
        a      : in  fp_t;
        b      : in  fp_t;
        result : out fp_t;
        done   : out std_logic
    );
end entity;

architecture rtl of fp_add_sub is

    type state_t is (S_IDLE, S_ALIGN, S_COMPUTE, S_NORMALIZE);
    signal state : state_t := S_IDLE;

    signal reg_a   : fp_t;
    signal reg_b   : fp_t;
    signal reg_exp : signed(15 downto 0);

    signal reg_ma  : signed(16 downto 0);
    signal reg_mb  : signed(16 downto 0);

    signal norm_in  : fp_t;
    signal norm_out : fp_t;

    signal reg_result : fp_t := FP_ZERO;

begin

    normalize_inst : entity work.fp_normalize
        port map (
            fp_in  => norm_in,
            fp_out => norm_out
        );

    norm_in.mantissa <= reg_a.mantissa;
    norm_in.exponent <= reg_exp;

    result <= reg_result;

    process(clk, reset)
        variable idiff : integer;
        variable sum_m : signed(16 downto 0);
    begin
        if reset = '1' then
            state      <= S_IDLE;
            done       <= '0';
            reg_result <= FP_ZERO;
        elsif rising_edge(clk) then
            done <= '0';

            case state is

                when S_IDLE =>
                    if start = '1' then
                        reg_a <= a;
                        reg_b <= b;
                        state <= S_ALIGN;
                    end if;

                when S_ALIGN =>
                    idiff := to_integer(reg_a.exponent - reg_b.exponent);

                    if idiff > 0 then
                        reg_exp <= reg_a.exponent;
                        reg_ma  <= resize(reg_a.mantissa, 17);
                        if idiff >= 15 then
                            reg_mb <= (others => '0');
                        else
                            reg_mb <= resize(shift_right(reg_b.mantissa, idiff), 17);
                        end if;

                    elsif idiff < 0 then
                        reg_exp <= reg_b.exponent;
                        reg_mb  <= resize(reg_b.mantissa, 17);
                        if (-idiff) >= 15 then
                            reg_ma <= (others => '0');
                        else
                            reg_ma <= resize(shift_right(reg_a.mantissa, -idiff), 17);
                        end if;

                    else
                        reg_exp <= reg_a.exponent;
                        reg_ma  <= resize(reg_a.mantissa, 17);
                        reg_mb  <= resize(reg_b.mantissa, 17);
                    end if;

                    state <= S_COMPUTE;

                when S_COMPUTE =>
                    if op = '0' then
                        sum_m := reg_ma + reg_mb;
                    else
                        sum_m := reg_ma - reg_mb;
                    end if;

                    if sum_m(16) /= sum_m(15) then
                        reg_a.mantissa <= sum_m(16 downto 1);
                        reg_exp        <= reg_exp + 1;
                    else
                        reg_a.mantissa <= sum_m(15 downto 0);
                        reg_exp        <= reg_exp;
                    end if;

                    state <= S_NORMALIZE;

                when S_NORMALIZE =>
                    reg_result <= norm_out;
                    done       <= '1';
                    state      <= S_IDLE;

            end case;
        end if;
    end process;

end architecture;
