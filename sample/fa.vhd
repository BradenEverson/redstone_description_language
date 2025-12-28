entity FA is
port(	A, B, CIN	: 	in 	std_logic;
		COUT, S		: 	out 	std_logic);
end entity FA;

architecture LOGIC of FA is
begin
	COUT <= (A and B) or (A and CIN) or (B and CIN);
	S <= (A xor B) xor CIN;
end architecture LOGIC;
