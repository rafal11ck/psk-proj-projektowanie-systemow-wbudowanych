library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity fp_mul is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;
        start  : in  std_logic;
        a      : in  fp_t;
        b      : in  fp_t;
        result : out fp_t;
        done   : out std_logic
    );
end entity;

architecture rtl of fp_mul is
    type state_t is (S_IDLE, S_COMPUTE, S_NORMALIZE);
    signal state : state_t := S_IDLE;

    signal reg_a      : fp_t;
    signal reg_b      : fp_t;
    signal reg_exp    : signed(15 downto 0);
    signal norm_in    : fp_t;
    signal norm_out   : fp_t;
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
        variable product : signed(31 downto 0);
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
                        state <= S_COMPUTE;
                    end if;

                when S_COMPUTE =>
                    product := reg_a.mantissa * reg_b.mantissa;

                    reg_a.mantissa <= product(30 downto 15);

                    reg_exp <= reg_a.exponent + reg_b.exponent;
                    state   <= S_NORMALIZE;

                when S_NORMALIZE =>
                    reg_result <= norm_out;
                    done       <= '1';
                    state      <= S_IDLE;
            end case;
        end if;
    end process;
end architecture;
