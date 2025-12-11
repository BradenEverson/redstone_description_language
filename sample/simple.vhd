-- I will probably not require this
-- library ieee;
-- use ieee.std_logic_1164.all;

entity FIVE_DETECTOR is
    port(
        A2, A1, A0: in std_logic;
        Y:  out std_logic);
end entity FIVE_DETECTOR;

architecture LOGIC of FIVE_DETECTOR is
begin
    Y <= A2 and not A1 and A0;
end architecture LOGIC;
