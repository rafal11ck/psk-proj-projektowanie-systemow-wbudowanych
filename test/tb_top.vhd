-- Testbench dla calego projektu - 14 testow.
-- Dwie sciezki testowe:
--   1) Przez top.vhd (testy 1-3): integracja licznikow + clk_div + auto-start +
--      mux + obsluga KEY/SW/LEDR/LEDG. Top napedzany jest dwoma licznikami
--      (fp_counter), wiec sprawdzamy stan po PIERWSZYM ticku (A=1/16, B=0).
--      DIV_MAX nadpisane na 6, zeby tick przychodzil szybko w symulacji.
--   2) Przez bezposrednie instancje fp_add_sub i fp_mul (testy 4-14): przypadki
--      brzegowe z dowolnymi wartosciami a, b (pelne pokrycie algorytmu, w tym
--      oba operandy niezerowe -- czego sciezka top nie sprawdza wprost).
--
-- Struktura: top.vhd = liczniki (input stage) + alu.vhd; alu.vhd = fp_add_sub + fp_mul + mux.
-- W GTKWave (task wave) widoczna jest cala hierarchia:
--   tb_top/dut_top/...                       sygnaly top.vhd (reset_sig, start_sig, a_in, b_in, LEDR, LEDG)
--   tb_top/dut_top/alu_inst/...              sygnaly alu.vhd (mux wyniku)
--   tb_top/dut_top/alu_inst/add_sub_inst/... rejestry fp_add_sub w ALU
--   tb_top/dut_top/alu_inst/mul_inst/...     rejestry fp_mul w ALU
--   tb_top/dut_add_sub/...                   dodatkowa instancja fp_add_sub (testy brzegowe)
--   tb_top/dut_mul/...                       dodatkowa instancja fp_mul (testy brzegowe)
-- Uruchomienie: task test (lub task wave dla GTKWave)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity tb_top is
end entity;

architecture sim of tb_top is

    signal clk : std_logic := '0';

    -- Sygnaly dla top.vhd (sciezka 1):
    signal sw   : std_logic_vector(15 downto 0) := (others => '0');
    signal key  : std_logic_vector(3  downto 0) := "1111";
    signal ledr : std_logic_vector(15 downto 0);
    signal ledg : std_logic_vector(8  downto 0);

    -- Sygnaly dla bezposrednich instancji (sciezka 2):
    signal reset : std_logic := '1';
    signal start : std_logic := '0';
    signal op    : std_logic := '0';   -- 0=ADD, 1=SUB
    signal a     : fp_t := FP_ZERO;
    signal b     : fp_t := FP_ZERO;
    signal as_result  : fp_t;
    signal as_done    : std_logic;
    signal mul_result : fp_t;
    signal mul_done   : std_logic;

    constant CLK_PERIOD : time := 20 ns;

    -- Czytelne stale dla mantys (interpretacja ulamkowa U2, README rozdzial 3):
    constant POS_HALF        : signed(15 downto 0) := to_signed( 16384, 16);  -- +0.5    = 0x4000
    constant POS_HALF_M1     : signed(15 downto 0) := to_signed( 16383, 16);  -- 0.5-eps = 0x3FFF
    constant POS_NEAR_ONE    : signed(15 downto 0) := to_signed( 32767, 16);  -- ~+1.0   = 0x7FFF
    constant NEG_HALF        : signed(15 downto 0) := to_signed(-16384, 16);  -- -0.5    = 0xC000
    constant NEG_ONE         : signed(15 downto 0) := to_signed(-32768, 16);  -- -1.0    = 0x8000
    constant ZERO_M          : signed(15 downto 0) := to_signed(     0, 16);

begin

    -- DUT 1: top.vhd - testy integracji przez interfejs plytki.
    -- DIV_MAX=6 => tick co 7 cykli (szybko, dla symulacji).
    dut_top : entity work.top
        generic map ( CLK_DIV_MAX => 6 )
        port map (
            CLOCK_50 => clk,
            SW       => sw,
            KEY      => key,
            LEDR     => ledr,
            LEDG     => ledg
        );

    -- DUT 2: dodatkowa instancja fp_add_sub dla testow brzegowych.
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

    -- DUT 3: dodatkowa instancja fp_mul dla testow brzegowych.
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

        -- Reset obu sciezek:
        --   top.vhd: KEY[0]='0' (active-low) -> reset_sig='1' wewnatrz top
        --   bezposrednie instancje: reset='1'
        reset <= '1';
        key   <= "1110";
        wait for 3 * CLK_PERIOD;
        reset <= '0';
        key   <= "1111";
        wait for CLK_PERIOD;

        -- TESTY PRZEZ TOP.VHD (sciezka 1, wejscia z licznikow)
        --
        -- Po resecie liczniki sa w 0. Pierwszy tick (DIV_MAX=6 -> 7 zbocze po
        -- deasercji resetu) inkrementuje licznik A do 1, B zostaje 0:
        --   A = 1/16 = 0.0625 (mantysa 0x0800, exp 0),   B = 0.
        -- Auto-start odpala obliczenie; wynik jest gotowy po ~11 zboczu i stabilny
        -- az do 2. ticku. Liczymy 13 zbocz po deasercji resetu i probkujemy.

        -- TEST 1: top ADD (SW[1:0]="00") -> 0.0625 + 0 = 0.0625
        -- COMPUTE: 0x0800 + 0 = 0x0800; bez overflow.
        -- NORMALIZE: 0x0800 -> 3 shifty -> 0x4000, exp = -3.
        -- LEDR=0x4000 (mantysa=+0.5), LEDG = (-3)[8:0] = "111111101".
        key <= "1110";                                          -- reset top (liczniki -> 0)
        sw(1 downto 0) <= "00";
        for i in 1 to 3 loop wait until rising_edge(clk); end loop;
        key <= "1111";                                          -- zwolnij reset
        for i in 1 to 13 loop wait until rising_edge(clk); end loop;

        assert ledr = x"4000"
            report "TEST 1 FAIL: top ADD 0.0625+0, oczekiwano LEDR=0x4000" severity ERROR;
        assert ledr /= x"4000"
            report "TEST 1 PASS: top ADD 0.0625+0 -> LEDR=0x4000 (mantysa=+0.5)" severity NOTE;
        assert ledg = "111111101"
            report "TEST 1 FAIL: top ADD, oczekiwano LEDG=-3 (111111101)" severity ERROR;
        assert ledg /= "111111101"
            report "TEST 1 PASS: top ADD -> LEDG=-3 (po normalizacji 0.0625)" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 2: top SUB (SW[1:0]="01") -> 0.0625 - 0 = 0.0625
        -- COMPUTE: 0x0800 - 0 = 0x0800; reszta jak TEST 1.
        -- LEDR=0x4000, LEDG="111111101".
        key <= "1110";
        sw(1 downto 0) <= "01";
        for i in 1 to 3 loop wait until rising_edge(clk); end loop;
        key <= "1111";
        for i in 1 to 13 loop wait until rising_edge(clk); end loop;

        assert ledr = x"4000"
            report "TEST 2 FAIL: top SUB 0.0625-0, oczekiwano LEDR=0x4000" severity ERROR;
        assert ledr /= x"4000"
            report "TEST 2 PASS: top SUB 0.0625-0 -> LEDR=0x4000 (mantysa=+0.5)" severity NOTE;
        assert ledg = "111111101"
            report "TEST 2 FAIL: top SUB, oczekiwano LEDG=-3 (111111101)" severity ERROR;
        assert ledg /= "111111101"
            report "TEST 2 PASS: top SUB -> LEDG=-3" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 3: top MUL (SW[1:0]="10") -> 0.0625 * 0 = 0
        -- COMPUTE: product=0 -> mantysa=0, exp=0+0=0; NORMALIZE pomija zero.
        -- LEDR=0x0000, LEDG=0.
        key <= "1110";
        sw(1 downto 0) <= "10";
        for i in 1 to 3 loop wait until rising_edge(clk); end loop;
        key <= "1111";
        for i in 1 to 13 loop wait until rising_edge(clk); end loop;

        assert ledr = x"0000"
            report "TEST 3 FAIL: top MUL 0.0625*0, oczekiwano LEDR=0x0000" severity ERROR;
        assert ledr /= x"0000"
            report "TEST 3 PASS: top MUL 0.0625*0 -> LEDR=0x0000 (mnozenie przez 0)" severity NOTE;
        assert ledg = "000000000"
            report "TEST 3 FAIL: top MUL, oczekiwano LEDG=0" severity ERROR;
        assert ledg /= "000000000"
            report "TEST 3 PASS: top MUL -> LEDG=0" severity NOTE;

        -- Od teraz top tyka swobodnie w tle; testy 4-14 uzywaja osobnych instancji.
        key <= "1111";
        wait for 2 * CLK_PERIOD;

        -- TESTY BRZEGOWE ADD/SUB (sciezka 2, dowolne a, b)

        -- TEST 4: ADD overflow mantysy - 0x7FFF + 0x7FFF
        -- COMPUTE: sum=0x0FFFE (17-bit); bit16=0, bit15=1 -> overflow
        -- po >>1: mantysa=0x7FFF, exp=1
        a <= (mantissa => POS_NEAR_ONE, exponent => to_signed(0, 16));
        b <= (mantissa => POS_NEAR_ONE, exponent => to_signed(0, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_NEAR_ONE
            report "TEST 4 FAIL: ADD overflow, oczekiwano +32767 (0x7FFF), otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_NEAR_ONE
            report "TEST 4 PASS: ADD overflow mantysy -> mantysa=0x7FFF" severity NOTE;
        assert as_result.exponent = to_signed(1, 16)
            report "TEST 4 FAIL: ADD overflow, oczekiwano wykladnik=1, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(1, 16)
            report "TEST 4 PASS: ADD overflow -> wykladnik=1 (przesuniety o 1)" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 5: SUB do zera - A - A = 0
        -- COMPUTE SUB: 0x4000 - 0x4000 = 0; brak overflow
        -- NORMALIZE: m=0 -> petla pominieta
        a <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0, 16));
        op <= '1';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = ZERO_M
            report "TEST 5 FAIL: SUB A-A, oczekiwano 0, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= ZERO_M
            report "TEST 5 PASS: SUB do zera -> mantysa=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 6: SUB wymagajace masywnej normalizacji (14 przesuniec)
        -- mA=0x4000 (0.5), mB=0x3FFF (0.5-2^-15), oba eA=eB=0
        -- COMPUTE SUB: 0x4000 - 0x3FFF = 0x0001
        -- NORMALIZE: po 14 shiftach m=0x4000, e=0-14=-14
        a <= (mantissa => POS_HALF,    exponent => to_signed(0, 16));
        b <= (mantissa => POS_HALF_M1, exponent => to_signed(0, 16));
        op <= '1';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 6 FAIL: SUB blisko zera, oczekiwano +0.5 (0x4000), otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 6 PASS: SUB blisko zera -> mantysa=0x4000 po 14 shiftach" severity NOTE;
        assert as_result.exponent = to_signed(-14, 16)
            report "TEST 6 FAIL: SUB blisko zera, oczekiwano -14, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(-14, 16)
            report "TEST 6 PASS: SUB blisko zera -> wykladnik=-14 (kompensacja)" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 7: ADD ujemnej i dodatniej - 1.0 + (-0.5) = 0.5
        -- A=(0.5, eA=1)=1.0; B=(-0.5, eB=0)=-0.5
        -- ALIGN: idiff=1 -> mB'=shift_right(0xC000, 1)=0xE000 (-0.25)
        -- COMPUTE ADD: 0x04000 + 0x1E000 = 0x02000; bez overflow
        -- NORMALIZE: 0x2000 -> 0x4000, e=0
        a <= (mantissa => POS_HALF, exponent => to_signed(1, 16));
        b <= (mantissa => NEG_HALF, exponent => to_signed(0, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 7 FAIL: ADD 1.0+(-0.5), oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 7 PASS: ADD ujemna+dodatnia -> mantysa=+0.5" severity NOTE;
        assert as_result.exponent = to_signed(0, 16)
            report "TEST 7 FAIL: ADD 1.0+(-0.5), oczekiwano wykladnik=0, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(0, 16)
            report "TEST 7 PASS: ADD ujemna+dodatnia -> wykladnik=0" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 8: ADD z idiff >= 15 - mniejsza wartosc znika
        -- A=(0.5, eA=20), B=(0.5, eB=0)
        -- ALIGN: idiff=20 >= 15 -> reg_mb=(others=>'0'); B przepada
        -- Wynik: A bez zmian, B caly traci sie (utrata precyzji)
        a <= (mantissa => POS_HALF, exponent => to_signed(20, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(0,  16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 8 FAIL: ADD idiff>=15, oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 8 PASS: ADD idiff>=15 -> B znika, mantysa=+0.5" severity NOTE;
        assert as_result.exponent = to_signed(20, 16)
            report "TEST 8 FAIL: ADD idiff>=15, oczekiwano 20, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(20, 16)
            report "TEST 8 PASS: ADD idiff>=15 -> wykladnik=20" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 9: ADD z ujemnym wykladnikiem (overflow zwieksza go z -5 do -4)
        -- A=B=(0.5, eA=eB=-5)
        -- COMPUTE ADD: sum=0x08000 (17-bit); bit16=0, bit15=1 -> overflow
        -- po >>1: mantysa=0x4000, exp=-5+1=-4
        -- Sprawdza arytmetyke wykladnikow ujemnych przy overflow.
        a <= (mantissa => POS_HALF, exponent => to_signed(-5, 16));
        b <= (mantissa => POS_HALF, exponent => to_signed(-5, 16));
        op <= '0';
        wait for CLK_PERIOD;
        start <= '1'; wait for CLK_PERIOD; start <= '0';
        wait until as_done = '1';
        wait for CLK_PERIOD;

        assert as_result.mantissa = POS_HALF
            report "TEST 9 FAIL: ADD ujemny exp, oczekiwano +0.5, otrzymano "
                 & integer'image(to_integer(as_result.mantissa)) severity ERROR;
        assert as_result.mantissa /= POS_HALF
            report "TEST 9 PASS: ADD ujemny wykladnik -> mantysa=+0.5" severity NOTE;
        assert as_result.exponent = to_signed(-4, 16)
            report "TEST 9 FAIL: ADD ujemny exp, oczekiwano -4, otrzymano "
                 & integer'image(to_integer(as_result.exponent)) severity ERROR;
        assert as_result.exponent /= to_signed(-4, 16)
            report "TEST 9 PASS: ADD ujemny wykladnik (overflow) -> wykladnik=-4" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TESTY BRZEGOWE MUL (sciezka 2)

        -- TEST 10: MUL przez zero
        -- A=0 eA=5, B=0x4000 eB=2
        -- product = 0; reg_a.mantissa = 0; exp = 5+2 = 7
        -- NORMALIZE: m=0 -> petla pominieta, exp niezmieniony
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

        -- TEST 11: MUL dwoch ujemnych - (-0.5) * (-0.5) = +0.25 = 0.5*2^-1
        -- mA=mB=-16384 (0xC000), eA=eB=0
        -- product = (-16384)*(-16384) = +268435456 = 0x10000000
        -- product[30:15] = 0x2000 (+8192), exp=0
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
        -- A=(+0.5, eA=1)=1.0; B=(-0.5, eB=2)=-2.0
        -- product = 16384*(-16384) = -268435456 = 0xF0000000
        -- product[30:15] = 0xE000 (-8192), exp = 1+2 = 3
        --
        -- KLUCZ: warunek nieznormalizowany = bit15==bit14
        --   0xE000 (1110...) bit15=1, bit14=1 -> shift -> 0xC000, e=2
        --   0xC000 (1100...) bit15=1, bit14=1 -> shift -> 0x8000, e=1  (!)
        --   0x8000 (1000...) bit15=1, bit14=0 -> stop
        -- Czyli -0.5 (0xC000) NIE jest znormalizowane: zakres znormalizowanych
        -- ujemnych to [-1.0, -0.5) bez samego -0.5. Wynik: -1.0 * 2^1 = -2.0
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
        -- product[30:15] = 0x2000, exp=200; po normalizacji 0x4000, exp=199
        -- Suma wykladnikow miesci sie w signed 16-bit (max +32767).
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

        -- TEST 14: PRZEPELNIENIE wykladnika - znane ograniczenie (README rozdzial 5)
        -- A=(0.5, eA=20000), B=(0.5, eB=20000)
        -- 20000+20000=40000 > 32767 -> wrap U2 do 40000-65536=-25536
        -- Po normalizacji (0x2000->0x4000): exp=-25537
        -- Modul NIE wykrywa overflow wykladnika - ten test dokumentuje to zachowanie.
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
