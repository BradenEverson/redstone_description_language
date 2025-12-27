-- RHDL compiler does not require std_logic imports
-- library ieee;
-- use ieee.std_logic_1164.all;

-- block diagram symbol
entity FA is
port(	A, B, CIN	: 	in 	std_logic;
		COUT, S		: 	out 	std_logic);
end entity FA;

-- circuit design
architecture LOGIC of FA is
begin
	COUT <= (A and B) or (A and CIN) or (B and CIN);
	S <= (A xor B) xor CIN;
end architecture LOGIC;
