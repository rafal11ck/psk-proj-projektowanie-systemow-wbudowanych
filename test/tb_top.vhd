-- Testbench dla top.vhd. Tylko do symulacji -- nie syntezuje sie na FPGA.
-- Plik w test/, nie w src/ -- nie dodawaj do projektu Quartus.
-- Jak uruchomic w ModelSim: README.md rozdzial 7.
-- Testuje: ADD(1.0+0.5=1.5), SUB(1.0-0.5=0.5), MUL(1.0*0.5=0.5)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

-- Testbench nie ma portow -- to zamkniety swiat symulacji.
entity tb_top is
end entity;

architecture sim of tb_top is

    -- Sygnaly odpowiadajace portom entity top.
    -- Inicjalizacja: clk='0', KEY="1111" (nic nie wcisniety = active-low).
    signal clk  : std_logic := '0';
    signal sw   : std_logic_vector(15 downto 0) := (others => '0');
    signal key  : std_logic_vector(3  downto 0) := "1111";
    signal ledr : std_logic_vector(15 downto 0);

    -- Okres zegara jako stala czasowa. "time" to typ VHDL tylko dla symulacji.
    constant CLK_PERIOD : time := 20 ns;  -- 50 MHz

begin

    -- Instancja testowanego modulu (DUT = Device Under Test).
    dut : entity work.top
        port map (
            CLOCK_50 => clk,
            SW       => sw,
            KEY      => key,
            LEDR     => ledr
        );

    -- Generator zegara: process bez listy czulosci z "wait" wykonuje sie w nieskonczonej petli.
    -- "after" i "wait for" to konstrukcje tylko symulacyjne.
    clk_proc : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    -- Glowny process sterujacy: generuje sekwencje testow.
    -- "wait for N * CLK_PERIOD" = odczekaj N cykli zegara.
    stim_proc : process
    begin

        -- Reset: KEY[0]='0' -> reset aktywny (active-low).
        key <= "1110";
        wait for 3 * CLK_PERIOD;
        key <= "1111";  -- zwolnij reset
        wait for CLK_PERIOD;

        -- TEST 1: ADD (SW[1:0]="00")
        -- Oczekiwany wynik mantysy: 0x6000 (+0.75 * 2^1 = 1.5)
        sw(1 downto 0) <= "00";
        wait for CLK_PERIOD;
        key <= "1101";              -- KEY[1]='0' -> start=1
        wait for CLK_PERIOD;
        key <= "1111";              -- KEY[1]='1' -> start=0
        wait for 6 * CLK_PERIOD;   -- czekaj na wynik (ADD potrzebuje 4 cykli po start)

        -- assert: jesli warunek falszywy -> ModelSim wypisze blad do konsoli.
        -- x"6000" to hex literal dla std_logic_vector.
        assert ledr = x"6000"
            report "TEST 1 FAIL: ADD 1.0+0.5, oczekiwano 0x6000" severity ERROR;
        assert ledr = x"6000"
            report "TEST 1 PASS: ADD 1.0+0.5 -> mantysa=0x6000" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 2: SUB (SW[1:0]="01")
        -- Oczekiwany wynik mantysy: 0x4000 (+0.5 * 2^0 = 0.5)
        sw(1 downto 0) <= "01";
        wait for CLK_PERIOD;
        key <= "1101"; wait for CLK_PERIOD; key <= "1111";
        wait for 6 * CLK_PERIOD;

        assert ledr = x"4000"
            report "TEST 2 FAIL: SUB 1.0-0.5, oczekiwano 0x4000" severity ERROR;
        assert ledr = x"4000"
            report "TEST 2 PASS: SUB 1.0-0.5 -> mantysa=0x4000" severity NOTE;

        wait for 2 * CLK_PERIOD;

        -- TEST 3: MUL (SW[1:0]="10")
        -- Oczekiwany wynik mantysy: 0x4000 (+0.5 * 2^0 = 0.5)
        sw(1 downto 0) <= "10";
        wait for CLK_PERIOD;
        key <= "1101"; wait for CLK_PERIOD; key <= "1111";
        wait for 6 * CLK_PERIOD;   -- MUL potrzebuje 3 cykli po start

        assert ledr = x"4000"
            report "TEST 3 FAIL: MUL 1.0*0.5, oczekiwano 0x4000" severity ERROR;
        assert ledr = x"4000"
            report "TEST 3 PASS: MUL 1.0*0.5 -> mantysa=0x4000" severity NOTE;

        wait for 5 * CLK_PERIOD;

        report "=== Wszystkie testy zakonczone ===" severity NOTE;
        wait;  -- zatrzymaj symulacje (zawies process na zawsze)

    end process;

end architecture;
