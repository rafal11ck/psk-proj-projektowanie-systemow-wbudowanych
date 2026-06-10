-- Top-level (wrapper plytki): podlacza wejscia/wyjscia do pinow plytki.
-- WLASCIWY uklad arytmetyczny jest w alu.vhd; tutaj tylko go instancjonujemy
-- i KARMIMY jego wejscia.
--
-- LICZNIKI SA PODPIETE NA WEJSCIE alu (porty a/b) -- z zewnatrz, tak samo jak
-- stimulus w testbenchu. NIE sa czescia ukladu arytmetycznego.
--   clk_div spowalnia 50 MHz do ~4 Hz (tick),
--   licznik A przechodzi przez dodatnia i ujemna pile co tick,
--   licznik B robi to samo, ale dopiero gdy A zatoczy pelne kolo (odometr),
--   dzieki czemu przewijaja sie wszystkie kombinacje (A, B),
--   start generowany jest automatycznie po kazdym ticku.
-- Dzieki temu na diodach widac na zywo, jak wynik zmienia sie z liczbami.
--
-- STEROWANIE:
--   KEY[0]   = reset (active-low)
--   SW[1:0]  = operacja (00=ADD, 01=SUB, 10=MUL)
--   SW[3:2]  = podglad LEDR (00=wynik, 01=A, 10=B)
-- LEDG pokazuje dolne bity wykladnika wyniku.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity top is
    generic (
        -- Dzielnik zegara: tick co (CLK_DIV_MAX+1) cykli. ~4 Hz dla 50 MHz.
        -- Testbench nadpisuje mala wartoscia, zeby symulacja byla szybka.
        CLK_DIV_MAX : natural := 12_500_000
    );
    port (
        CLOCK_50 : in  std_logic;
        SW       : in  std_logic_vector(15 downto 0);  -- SW[1:0] = operacja
        KEY      : in  std_logic_vector(3  downto 0);  -- active-low: wcisniety='0'
        LEDR     : out std_logic_vector(15 downto 0);  -- mantysa wyniku
        LEDG     : out std_logic_vector(8  downto 0)   -- dolne bity wykladnika wyniku
    );
end entity;

architecture rtl of top is

    signal reset_sig  : std_logic;
    signal tick       : std_logic;  -- impuls ~4 Hz z dzielnika
    signal carry_a    : std_logic;  -- '1' gdy licznik A sie przewija (taktuje B)
    signal start_sig  : std_logic;  -- auto-start: tick opozniony o 1 cykl

    -- Wejscia ALU generowane przez liczniki (input stage):
    signal a_in       : fp_t;
    signal b_in       : fp_t;

    -- Wyjscie ALU:
    signal alu_result : fp_t;

begin

    -- KEY[0] active-low: wcisniety -> reset_sig='1' (active high dla modulow).
    reset_sig <= not KEY(0);

    -- === INPUT STAGE: generatory liczb podpiete na wejscia ALU ===

    -- Dzielnik zegara 50 MHz -> powolny impuls 'tick'.
    clkdiv_inst : entity work.clk_div
        generic map ( DIV_MAX => CLK_DIV_MAX )
        port map (
            clk   => CLOCK_50,
            reset => reset_sig,
            tick  => tick
        );

    -- Licznik A: szybka pila signed, tyka na kazdy tick.
    counter_a_inst : entity work.fp_counter
        port map (
            clk   => CLOCK_50,
            reset => reset_sig,
            en    => tick,
            value => a_in,
            carry => carry_a
        );

    -- Licznik B: wolna pila signed, tyka po pelnym obiegu A (odometr).
    counter_b_inst : entity work.fp_counter
        port map (
            clk   => CLOCK_50,
            reset => reset_sig,
            en    => carry_a,
            value => b_in,
            carry => open
        );

    -- Auto-start: impuls startu jeden cykl po ticku. Opoznienie o 1 cykl
    -- gwarantuje, ze a_in/b_in (zmienione na ticku) sa juz stabilne, gdy ALU je zatrzaskuje.
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then
            if reset_sig = '1' then
                start_sig <= '0';
            else
                start_sig <= tick;
            end if;
        end if;
    end process;

    -- === UKLAD ARYTMETYCZNY: liczniki podpiete na jego wejscia a/b ===
    alu_inst : entity work.alu
        port map (
            clk    => CLOCK_50,
            reset  => reset_sig,
            start  => start_sig,
            op     => SW(1 downto 0),
            a      => a_in,
            b      => b_in,
            result => alu_result,
            done   => open
        );

    -- SW[3:2] pozwala sprawdzic na tych samych LED-ach wejscia i wynik.
    with SW(3 downto 2) select
        LEDR <= std_logic_vector(alu_result.mantissa) when "00",
                std_logic_vector(a_in.mantissa)       when "01",
                std_logic_vector(b_in.mantissa)       when "10",
                std_logic_vector(alu_result.mantissa) when others;

    LEDG <= std_logic_vector(alu_result.exponent(8 downto 0));

end architecture;
