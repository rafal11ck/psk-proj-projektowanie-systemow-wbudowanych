-- Modul dodawania i odejmowania zmiennoprzecinkowego.
-- Algorytm (4 kroki = 4 stany FSM): README.md rozdzial 5 i 6.
-- op=0: dodawanie, op=1: odejmowanie

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fp_pkg.all;

entity fp_add_sub is
    port (
        clk    : in  std_logic;
        reset  : in  std_logic;   -- synchroniczny reset, active high
        start  : in  std_logic;   -- impuls startu (1 cykl zegara)
        op     : in  std_logic;   -- 0=dodaj, 1=odejmij
        a      : in  fp_t;
        b      : in  fp_t;
        result : out fp_t;
        done   : out std_logic    -- high przez 1 cykl gdy wynik gotowy
    );
end entity;

architecture rtl of fp_add_sub is

    -- Typ wyliczeniowy (enum) dla stanow FSM.
    -- VHDL przechowuje go jako rejestr bitowy (2 bity dla 4 stanow).
    type state_t is (S_IDLE, S_ALIGN, S_COMPUTE, S_NORMALIZE);
    signal state : state_t := S_IDLE;

    signal reg_a   : fp_t;                 -- zatrzasniete wejscie a (z momentu start=1)
    signal reg_b   : fp_t;                 -- zatrzasniete wejscie b
    signal reg_exp : signed(15 downto 0);  -- roboczy wykladnik wspolny po wyrownaniu

    -- Wyrownane mantysy: 17 bitow zamiast 16, zeby zmiescic bit przepelnienia przy dodawaniu.
    -- resize(x, 17) rozszerza x z 16 na 17 bitow, kopiujac bit znaku na pozycje 16.
    signal reg_ma  : signed(16 downto 0);
    signal reg_mb  : signed(16 downto 0);

    -- Polaczenie z kombinacyjnym modulem normalizacji.
    -- norm_in wchodzi do modulu, norm_out wychodzi -- bez opoznienia zegarowego.
    signal norm_in  : fp_t;
    signal norm_out : fp_t;

    signal reg_result : fp_t := FP_ZERO;

begin

    -- Instancja normalizatora. "entity work.fp_normalize" = szukaj w projekcie modulu fp_normalize.
    -- port map = podlaczenie portow modulu do sygnalow lokalnych.
    normalize_inst : entity work.fp_normalize
        port map (
            fp_in  => norm_in,
            fp_out => norm_out
        );

    -- Concurrent assignments: te linie dzialaja jak ciagle polaczenia (nie w procesie).
    -- norm_in zawsze odzwierciedla reg_a.mantissa i reg_exp -- kombinacyjnie, bez zegara.
    norm_in.mantissa <= reg_a.mantissa;
    norm_in.exponent <= reg_exp;

    result <= reg_result;

    -- Synchroniczny process: lista czulosci = tylko clk.
    -- Caly kod wewnatrz rising_edge(clk) wykonuje sie tylko na zboczu narastajacym.
    process(clk)
        -- variable: natychmiastowe przypisanie (:=), lokalne dla tego procesu.
        -- Potrzebujemy integer dla to_integer() -- signed nie mozna porownywac z literalem.
        variable idiff : integer;
        variable sum_m : signed(16 downto 0);  -- 17-bitowy wynik sumy
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state      <= S_IDLE;
                done       <= '0';
                reg_result <= FP_ZERO;
            else
                done <= '0';  -- domyslnie done=0; ustawiamy na 1 tylko w S_NORMALIZE

                case state is

                    when S_IDLE =>
                        if start = '1' then
                            -- Zatrzasnij wejscia: od teraz reg_a i reg_b sa stabilne
                            -- przez cale obliczenia, nawet jesli a i b sie zmienia.
                            reg_a <= a;
                            reg_b <= b;
                            state <= S_ALIGN;
                        end if;

                    when S_ALIGN =>
                        -- to_integer() konwertuje signed na integer -- potrzebne bo VHDL
                        -- nie pozwala porownywac signed z literalem bez konwersji.
                        idiff := to_integer(reg_a.exponent - reg_b.exponent);

                        if idiff > 0 then
                            -- eA > eB: wyrownaj B do wykladnika A.
                            -- shift_right na signed = arytmetyczne przesuniecie (zachowuje znak).
                            -- resize(x, 17) = rozszerz 16->17 bitow, kopiujac bit znaku.
                            reg_exp <= reg_a.exponent;
                            reg_ma  <= resize(reg_a.mantissa, 17);
                            if idiff >= 15 then
                                reg_mb <= (others => '0');  -- roznica tak duza ze B ~= 0
                            else
                                reg_mb <= resize(shift_right(reg_b.mantissa, idiff), 17);
                            end if;

                        elsif idiff < 0 then
                            -- eB > eA: wyrownaj A do wykladnika B.
                            reg_exp <= reg_b.exponent;
                            reg_mb  <= resize(reg_b.mantissa, 17);
                            if (-idiff) >= 15 then
                                reg_ma <= (others => '0');
                            else
                                reg_ma <= resize(shift_right(reg_a.mantissa, -idiff), 17);
                            end if;

                        else
                            -- Wykladniki rowne -- bez przesuniecia.
                            reg_exp <= reg_a.exponent;
                            reg_ma  <= resize(reg_a.mantissa, 17);
                            reg_mb  <= resize(reg_b.mantissa, 17);
                        end if;

                        state <= S_COMPUTE;

                    when S_COMPUTE =>
                        if op = '0' then
                            sum_m := reg_ma + reg_mb;
                        else
                            -- Odejmowanie = dodawanie zanegowanej wartosci.
                            -- Operator - na signed dziala poprawnie dla U2.
                            sum_m := reg_ma - reg_mb;
                        end if;

                        -- Obsluga przepelnienia (overflow).
                        -- sum_m ma 17 bitow: bit16 to nadmiarowy bit znaku.
                        -- Jesli bit16 != bit15: wynik przekroczyl [-1,+1) -> przesun prawo, e++.
                        -- Jesli bit16 == bit15: wynik miesci sie w 16 bitach -> wez dolne 16.
                        -- Szczegoly: README.md rozdzial 5.
                        if sum_m(16) /= sum_m(15) then
                            reg_a.mantissa <= sum_m(16 downto 1);  -- przesun prawo o 1
                            reg_exp        <= reg_exp + 1;
                        else
                            reg_a.mantissa <= sum_m(15 downto 0);
                            reg_exp        <= reg_exp;  -- bez zmian (explicit zeby uniknac latcha)
                        end if;

                        state <= S_NORMALIZE;

                    when S_NORMALIZE =>
                        -- norm_out jest juz gotowy kombinacyjnie (fp_normalize dziala bez zegara).
                        -- reg_a.mantissa i reg_exp zostaly zaktualizowane w poprzednim cyklu
                        -- i norm_in/norm_out zdazyli sie ustabilizowac przed tym zboczem.
                        reg_result <= norm_out;
                        done       <= '1';
                        state      <= S_IDLE;

                end case;
            end if;
        end if;
    end process;

end architecture;
