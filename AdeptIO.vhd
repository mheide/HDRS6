library ieee;
use ieee.std_logic_1164.all;

entity AdeptIO is
	port(
		clk_i     : in    std_logic;
		rst_i     : in    std_logic;
		eppAstb_i : in    std_logic;
		eppDstb_i : in    std_logic;
		eppWr_i   : in    std_logic;
		eppDb_io  : inout std_logic_vector(7 downto 0);
		eppWait_o : out   std_logic;
		--user site
		led_i     : in    std_logic_vector(7 downto 0);
		lBar_i    : in    std_logic_vector(23 downto 0);
		sw_o      : out   std_logic_vector(15 downto 0);
		btn_o     : out   std_logic_vector(15 downto 0);
		dword_o   : out   std_logic_vector(31 downto 0);
		dword_i   : in    std_logic_vector(31 downto 0)
	);
end entity AdeptIO;

architecture RTL of AdeptIO is
	signal regEppAdr    : std_logic_vector(7 downto 0) := (others => '0');
	signal regVer       : std_logic_vector(7 downto 0) := (others => '0');
	signal busEppIntern : std_logic_vector(7 downto 0);
begin

	eppWaitPrc : process(clk_i, rst_i) is
	begin
		if rst_i = '1' then
			eppWait_o <= '0';
		elsif rising_edge(clk_i) then
			if eppAstb_i = '1' then
				eppWait_o <= '0';
			elsif eppDstb_i = '1' then
				eppWait_o <= '0';
			else
				eppWait_o <= '1';
			end if;
		end if;
	end process eppWaitPrc;

	busEppPrc : process(clk_i, rst_i) is
	begin
		if rst_i = '1' then
			eppDb_io     <= (others => '0');
			busEppIntern <= (others => '0');
			regEppAdr    <= (others => '0');
		elsif rising_edge(clk_i) then
			if eppWr_i = '0' then
				if eppAstb_i = '1' then
					regEppAdr <= eppDb_io;
				elsif eppDstb_i = '1' then
					case regEppAdr is
						when x"05"  => sw_o(7 downto 0) <= eppDb_io;
						when x"06"  => sw_o(15 downto 8) <= eppDb_io;
						when x"07"  => btn_o(7 downto 0) <= eppDb_io;
						when x"08"  => btn_o(15 downto 8) <= eppDb_io;
						when x"09"  => dword_o(7 downto 0) <= eppDb_io;
						when x"0a"  => dword_o(15 downto 8) <= eppDb_io;
						when x"0b"  => dword_o(23 downto 16) <= eppDb_io;
						when x"0c"  => dword_o(31 downto 24) <= eppDb_io;
						when others => regVer <= not eppDb_io;
					end case;
				end if;
			else                        --eppWr_i = '1'
				case regEppAdr is
					when x"01"  => busEppIntern <= led_i;
					when x"02"  => busEppIntern <= lBar_i(7 downto 0);
					when x"03"  => busEppIntern <= lBar_i(15 downto 8);
					when x"04"  => busEppIntern <= lBar_i(23 downto 16);
					when x"0d"  => busEppIntern <= dword_i(7 downto 0);
					when x"0e"  => busEppIntern <= dword_i(15 downto 8);
					when x"0F"  => busEppIntern <= dword_i(23 downto 16);
					when x"10"  => busEppIntern <= dword_i(31 downto 24);
					when others => busEppIntern(7 downto 0) <= regVer;
				end case;
				eppDb_io <= busEppIntern;
			end if;
		end if;
	end process busEppPrc;

end architecture RTL;
