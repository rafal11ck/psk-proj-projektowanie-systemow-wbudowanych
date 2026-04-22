library ieee;
use ieee.std_logic_1164.all;

entity top is
  port (
    CLOCK_50 : in  std_logic;
    SW       : in  std_logic_vector(15 downto 0);
    LEDR     : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of top is
  signal reg : std_logic_vector(15 downto 0) := (others => '0');
begin
  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      reg <= SW;
    end if;
  end process;

  LEDR <= reg;
end architecture;
