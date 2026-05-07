-- Testbench dla wszystkich modulow obliczeniowych - 14 testow w jednym pliku.
-- Instancjuje fp_add_sub i fp_mul bezposrednio, z pominieciem top.vhd
-- (top.vhd ma A_IN/B_IN jako stale - nie da sie zmieniac wejsc z testbenchu).
-- Uruchomienie: task test (lub task wave dla GTKWave)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity tb_top is
end entity;

architecture sim of tb_top is

    signal clk    : std_logic := '0';
    signal reset  : std_logic := '1';
    signal start  : std_logic := '0';
    signal op     : std_logic := '0';   -- 0=ADD, 1=SUB
    signal a      : fp_t := FP_ZERO;
    signal b      : fp_t := FP_ZERO;

    signal as_result  : fp_t;
    signal as_done    : std_logic;
    signal mul_result : fp_t;
    signal mul_done   : std_logic;

    constant CLK_PERIOD : time := 20 ns;

    -- Czytelne stale dla mantys (interpretacja ulamkowa U2, README rozdzial 3):
    constant POS_HALF        : signed(15 downto 0) := to_signed( 16384, 16);  -- +0.5    = 0x4000
    constant POS_HALF_M1     : signed(15 downto 0) := to_signed( 16383, 16);  -- 0.5-eps = 0x3FFF
    constant POS_THREE_QUART : signed(15 downto 0) := to_signed( 24576, 16);  -- +0.75   = 0x6000
    constant POS_NEAR_ONE    : signed(15 downto 0) := to_signed( 32767, 16);  -- ~+1.0   = 0x7FFF
    constant NEG_HALF        : signed(15 downto 0) := to_signed(-16384, 16);  -- -0.5    = 0xC000
    constant NEG_ONE         : signed(15 downto 0) := to_signed(-32768, 16);  -- -1.0    = 0x8000
    constant ZERO_M          : signed(15 downto 0) := to_signed(     0, 16);

begin

    -- Oba moduly polaczone z tymi samymi a, b, start. Oba ruszaja jednoczesnie,
    -- ale w danym tescie sprawdzamy tylko wynik wlasciwego modulu.
    dut_add_sub : entity work.fp_add_sub
        port map (
            clk    => clk,
            reset  => reset,
            start  => start,
            op     => op,
            a      => a,
            b      => b,
            result => as_result,
            done   => as_done
        );

    dut_mul : entity work.fp_mul
        port map (
            clk    => clk,
            reset  => reset,
            start  => start,
            a      => a,
            b      => b,
            result => mul_result,
            done   => mul_done
        );

    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    stim_proc : process
    begin

        reset <= '1';
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        wait for CLK_PERIOD;

        -- TESTY ADD/SUB (sprawdzaj as_result, czekaj na as_done)

        -- TEST 1: ADD 1.0 + 0.5 = 1.5 (test bazowy)
        -- ALIGN: idiff=1 -> mB'=0x2000; SUM: 0x4000+0x2000=0x6000; bez overflow
        a <= (mantissa => POS_HALF, exponent => to_signed(1, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_THREE_QUART
            report "TEST 1 FAIL: ADD 1.0+0.5, oczekiwano +24576 (0x6000), otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_THREE_QUART
            report "TEST 1 PASS: ADD 1.0+0.5 -> mantysa=+0.75 (0x6000)" severity NOTE;
        assert as_result.exponent = to_signed(1, 16)
            report "TEST 1 FAIL: ADD 1.0+0.5, oczekiwano wykladnik=1, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(1, 16)
            report "TEST 1 PASS: ADD 1.0+0.5 -> wykladnik=1" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 2: SUB 1.0 - 0.5 = 0.5 (test bazowy)
        a <= (mantissa => POS_HALF, exponent => to_signed(1, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        op <= '1';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 2 FAIL: SUB 1.0-0.5, oczekiwano +0.5 (0x4000), otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 2 PASS: SUB 1.0-0.5 -> mantysa=+0.5 (0x4000)" severity NOTE;
        assert as_result.exponent = to_signed(0, 16)
            report "TEST 2 FAIL: SUB 1.0-0.5, oczekiwano wykladnik=0, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(0, 16)
            report "TEST 2 PASS: SUB 1.0-0.5 -> wykladnik=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 3: ADD overflow mantysy - 0x7FFF + 0x7FFF
        -- COMPUTE: sum=0x0FFFE (17-bit); bit16=0, bit15=1 -> overflow!
        -- po >>1: mantysa=0x7FFF, exp=1
        a <= (mantissa => POS_NEAR_ONE, exponent => to_signed(0, 16));
        b <= (mantissa => POS_NEAR_ONE, exponent => to_signed(0, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_NEAR_ONE
            report "TEST 3 FAIL: ADD overflow, oczekiwano +32767 (0x7FFF), otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_NEAR_ONE
            report "TEST 3 PASS: ADD overflow mantysy -> mantysa=0x7FFF" severity NOTE;
        assert as_result.exponent = to_signed(1, 16)
            report "TEST 3 FAIL: ADD overflow, oczekiwano wykladnik=1, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(1, 16)
            report "TEST 3 PASS: ADD overflow -> wykladnik=1 (przesuniety o 1)" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 4: SUB do zera - A - A = 0
        -- NORMALIZE: m=0 -> petla pominieta
        a <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        op <= '1';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = ZERO_M
            report "TEST 4 FAIL: SUB A-A, oczekiwano 0, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= ZERO_M
            report "TEST 4 PASS: SUB do zera -> mantysa=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 5: SUB wymagajace masywnej normalizacji (14 przesuniec)
        -- 0x4000 - 0x3FFF = 0x0001 -> po 14 shiftach: m=0x4000, e=-14
        a <= (mantissa => POS_HALF,    exponent => to_signed(0, 16));
        b <= (mantissa => POS_HALF_M1, exponent => to_signed(0, 16));
        op <= '1';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 5 FAIL: SUB blisko zera, oczekiwano +0.5 (0x4000), otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 5 PASS: SUB blisko zera -> mantysa=0x4000 po 14 shiftach" severity NOTE;
        assert as_result.exponent = to_signed(-14, 16)
            report "TEST 5 FAIL: SUB blisko zera, oczekiwano -14, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(-14, 16)
            report "TEST 5 PASS: SUB blisko zera -> wykladnik=-14 (kompensacja)" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 6: ADD ujemnej i dodatniej - 1.0 + (-0.5) = 0.5
        a <= (mantissa => POS_HALF, exponent => to_signed(1, 16));
        b <= (mantissa => NEG_HALF, exponent => to_signed(0, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 6 FAIL: ADD 1.0+(-0.5), oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 6 PASS: ADD ujemna+dodatnia -> mantysa=+0.5" severity NOTE;
        assert as_result.exponent = to_signed(0, 16)
            report "TEST 6 FAIL: ADD 1.0+(-0.5), oczekiwano wykladnik=0, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(0, 16)
            report "TEST 6 PASS: ADD ujemna+dodatnia -> wykladnik=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 7: ADD z idiff >= 15 - mniejsza wartosc znika
        -- ALIGN: idiff=20 >= 15 -> reg_mb=0; B przepada
        a <= (mantissa => POS_HALF, exponent => to_signed(20, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0,  16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 7 FAIL: ADD idiff>=15, oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 7 PASS: ADD idiff>=15 -> B znika, mantysa=+0.5" severity NOTE;
        assert as_result.exponent = to_signed(20, 16)
            report "TEST 7 FAIL: ADD idiff>=15, oczekiwano 20, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(20, 16)
            report "TEST 7 PASS: ADD idiff>=15 -> wykladnik=20" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 8: ADD z ujemnym wykladnikiem (overflow zwieksza go z -5 do -4)
        a <= (mantissa => POS_HALF, exponent => to_signed(-5, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(-5, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 8 FAIL: ADD ujemny exp, oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 8 PASS: ADD ujemny wykladnik -> mantysa=+0.5" severity NOTE;
        assert as_result.exponent = to_signed(-4, 16)
            report "TEST 8 FAIL: ADD ujemny exp, oczekiwano -4, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(-4, 16)
            report "TEST 8 PASS: ADD ujemny wykladnik (overflow) -> wykladnik=-4" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TESTY MUL (sprawdzaj mul_result, czekaj na mul_done)

        -- TEST 9: MUL 1.0 * 0.5 = 0.5 (test bazowy)
        -- product[30:15] = 0x2000; po normalizacji 0x4000, exp=0
        a <= (mantissa => POS_HALF, exponent => to_signed(1, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until mul_done = '1';
        wait for CLK_PERIOD;

        assert mul_result.mantissa = POS_HALF
            report "TEST 9 FAIL: MUL 1.0*0.5, oczekiwano +0.5 (0x4000), otrzymano "
                 & integer'image(to_integer(mul_result.mantissa)) severity ERROR;
        assert mul_result.mantissa /= POS_HALF
            report "TEST 9 PASS: MUL 1.0*0.5 -> mantysa=+0.5 (0x4000)" severity NOTE;
        assert mul_result.exponent = to_signed(0, 16)
            report "TEST 9 FAIL: MUL 1.0*0.5, oczekiwano wykladnik=0, otrzymano "
                 & integer'image(to_integer(mul_result.exponent)) severity ERROR;
        assert mul_result.exponent /= to_signed(0, 16)
            report "TEST 9 PASS: MUL 1.0*0.5 -> wykladnik=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 10: MUL przez zero
        -- product = 0; NORMALIZE: m=0 -> petla pominieta, exp niezmieniony
        a <= (mantissa => ZERO_M,   exponent => to_signed(5, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(2, 16));
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until mul_done = '1';
        wait for CLK_PERIOD;

        assert mul_result.mantissa = ZERO_M
            report "TEST 10 FAIL: MUL 0*X, oczekiwano 0, otrzymano "
                 & integer'image(to_integer(mul_result.mantissa)) severity ERROR;
        assert mul_result.mantissa /= ZERO_M
            report "TEST 10 PASS: MUL przez 0 -> mantysa=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 11: MUL dwoch ujemnych - (-0.5) * (-0.5) = +0.25
        -- product = (-16384)*(-16384) = +0x10000000; product[30:15]=0x2000
        -- NORMALIZE: 0x2000 -> 0x4000, exp=-1
        a <= (mantissa => NEG_HALF, exponent => to_signed(0, 16));
        b <= (mantissa => NEG_HALF, exponent => to_signed(0, 16));
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until mul_done = '1';
        wait for CLK_PERIOD;

        assert mul_result.mantissa = POS_HALF
            report "TEST 11 FAIL: MUL (-0.5)*(-0.5), oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(mul_result.mantissa)) severity ERROR;
        assert mul_result.mantissa /= POS_HALF
            report "TEST 11 PASS: MUL (-)*( -) = (+) -> mantysa=+0.5 (0x4000)" severity NOTE;
        assert mul_result.exponent = to_signed(-1, 16)
            report "TEST 11 FAIL: MUL ujemnych, oczekiwano wykladnik=-1, otrzymano "
                 & integer'image(to_integer(mul_result.exponent)) severity ERROR;
        assert mul_result.exponent /= to_signed(-1, 16)
            report "TEST 11 PASS: MUL ujemnych -> wykladnik=-1" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 12: MUL roznych znakow - 1.0 * (-2.0) = -2.0
        -- KLUCZ: warunek nieznormalizowany = bit15==bit14
        --   product[30:15]=0xE000 (1110...) -> shift -> 0xC000 -> shift -> 0x8000
        -- Czyli -0.5 (0xC000) NIE jest znormalizowane: zakres znormalizowanych
        -- ujemnych to [-1.0, -0.5) bez samego -0.5. Wynik: -1.0 * 2^1 = -2.0.
        a <= (mantissa => POS_HALF, exponent => to_signed(1, 16));
        b <= (mantissa => NEG_HALF, exponent => to_signed(2, 16));
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until mul_done = '1';
        wait for CLK_PERIOD;

        assert mul_result.mantissa = NEG_ONE
            report "TEST 12 FAIL: MUL 1.0*(-2.0), oczekiwano -1.0 (0x8000), otrzymano "
                 & integer'image(to_integer(mul_result.mantissa)) severity ERROR;
        assert mul_result.mantissa /= NEG_ONE
            report "TEST 12 PASS: MUL rozne znaki -> mantysa=-1.0 (0x8000); -0.5 nieznormalizowane" severity NOTE;
        assert mul_result.exponent = to_signed(1, 16)
            report "TEST 12 FAIL: MUL 1.0*(-2.0), oczekiwano wykladnik=1, otrzymano "
                 & integer'image(to_integer(mul_result.exponent)) severity ERROR;
        assert mul_result.exponent /= to_signed(1, 16)
            report "TEST 12 PASS: MUL rozne znaki -> wykladnik=1 (-1.0 * 2 = -2.0)" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 13: MUL z duzymi (bezpiecznymi) wykladnikami: 100 + 100 = 200
        -- Suma miesci sie w signed 16-bit
        a <= (mantissa => POS_HALF, exponent => to_signed(100, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(100, 16));
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until mul_done = '1';
        wait for CLK_PERIOD;

        assert mul_result.mantissa = POS_HALF
            report "TEST 13 FAIL: MUL duze exp, oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(mul_result.mantissa)) severity ERROR;
        assert mul_result.mantissa /= POS_HALF
            report "TEST 13 PASS: MUL z duzymi wykladnikami -> mantysa=+0.5" severity NOTE;
        assert mul_result.exponent = to_signed(199, 16)
            report "TEST 13 FAIL: MUL duze exp, oczekiwano 199, otrzymano "
                 & integer'image(to_integer(mul_result.exponent)) severity ERROR;
        assert mul_result.exponent /= to_signed(199, 16)
            report "TEST 13 PASS: MUL duze exp -> wykladnik=199" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 14: PRZEPELNIENIE wykladnika (znane ograniczenie - README rozdzial 5)
        -- 20000+20000=40000 wraps U2 do -25536; po normalizacji exp=-25537
        -- Modul nie wykrywa overflow wykladnika.
        a <= (mantissa => POS_HALF, exponent => to_signed(20000, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(20000, 16));
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until mul_done = '1';
        wait for CLK_PERIOD;

        assert mul_result.exponent = to_signed(-25537, 16)
            report "TEST 14 FAIL: MUL exp overflow, oczekiwano -25537, otrzymano "
                 & integer'image(to_integer(mul_result.exponent)) severity ERROR;
        assert mul_result.exponent /= to_signed(-25537, 16)
            report "TEST 14 PASS: MUL exp overflow -> wykladnik=-25537 (znane ograniczenie U2)" severity NOTE;

        wait for 5 * CLK_PERIOD;

        report "=== Wszystkie testy zakonczone (14/14) ===" severity NOTE;
        wait;

    end process;

end architecture;
