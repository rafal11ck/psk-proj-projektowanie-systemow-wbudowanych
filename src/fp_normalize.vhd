-- Modul kombinacyjny: normalizuje mantysę tak zeby |m| >= 0.5
-- Algorytm: README.md rozdzial 5 "Normalizacja"
-- Kombinacyjny = brak zegara, wejscie -> wyjscie bez opoznienia zegarowego.

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

    -- Process kombinacyjny: lista czulosci = wszystkie wejscia.
    -- Reaguje na kazda zmiane fp_in, bez zegara.
    -- Uzywamy variable (nie signal) bo potrzebujemy natychmiastowych aktualizacji
    -- wewnatrz petli -- sygnaly bylby widoczne dopiero po zakonczeniu procesu.
    process(fp_in)
        variable m : signed(15 downto 0);
        variable e : signed(15 downto 0);
    begin
        m := fp_in.mantissa;
        e := fp_in.exponent;

        -- Nie normalizuj zera (petla by krecila sie bez sensu).
        -- to_signed(0, 16) tworzy 16-bitowe zero typu signed do porownania.
        if m /= to_signed(0, 16) then

            -- Petla for w procesie kombinacyjnym = 15 poziomow logiki (multipleksery),
            -- NIE wykonanie sekwencyjne w czasie. Syntezator ja "rozwija".
            -- Warunek: m(15) = m(14) oznacza ze dwa najstarsze bity sa takie same
            -- -> liczba nienormalizowana (|m| < 0.5). Patrz README.md rozdzial 3.
            for i in 0 to 14 loop
                if m(15) = m(14) then
                    m := shift_left(m, 1);  -- *2: przesun bity w lewo, LSB=0
                    e := e - 1;             -- kompensacja: zmniejsz wykladnik o 1
                end if;
            end loop;

        end if;

        fp_out.mantissa <= m;
        fp_out.exponent <= e;

    end process;

end architecture;
