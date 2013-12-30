----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    15:18:05 03/27/2012 
-- Design Name: 
-- Module Name:    HDR_wrapper - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

library digilent;
use digilent.Video.ALL;

library ieee_proposed;
use ieee_proposed.fixed_float_types.all; -- ieee_proposed for VHDL-93 version
use ieee_proposed.fixed_pkg.all; -- ieee_proposed for compatibility version

-- Global Settings
use work.hdr_pkg.ALL;

-- LUTs
use work.inverse_pkg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity HDR_wrapper is
    Port ( clk_i : in  STD_LOGIC;
           rst_i : in  STD_LOGIC;
           sw_i : in  STD_LOGIC;
			  FbRdDatap0		: 	in std_logic_vector(15 downto 0);
			  FbRdDatap3		:  in std_logic_vector(15 downto 0);
			  hdr_image_o         : out pixel_type);
end HDR_wrapper;

architecture Behavioral of HDR_wrapper is
	signal pictures : image_type;
	signal hdr_image : pixel_type;
begin
	process
	begin
		if sw_i = '0' then
			hdr_image_o.red <= FbRdDatap0(15 downto 11)&"000";
			hdr_image_o.green <= FbRdDatap0(10 downto 5)&"00";
			hdr_image_o.blue <= FbRdDatap0(4 downto 0)&"000";
--			pictures(0).red <= FbRdDatap0(15 downto 11)&"000";
--			pictures(0).green <= x"00";
--			pictures(0).blue <= x"00";
--			pictures(1).red <= FbRdDatap3(15 downto 11)&"000";
--			pictures(1).green <= x"00";
--			pictures(1).blue <= x"00";
		elsif sw_i = '1' then
			hdr_image_o.red <=  FbRdDatap3(15 downto 11)&"000";
			hdr_image_o.green <= FbRdDatap3(10 downto 5)&"00";
			hdr_image_o.blue <= FbRdDatap3(4 downto 0)&"000";
--			pictures(0).red <= x"00";
--			pictures(1).red <= x"00";
--			pictures(0).green <= FbRdDatap0(10 downto 5)&"00";
--			pictures(1).green <= FbRdDatap3(10 downto 5)&"00";
--			pictures(0).blue <= x"00";
--			pictures(1).blue <= x"00";
		--elsif sw_i(7 downto 6) = "10" then
--			pictures(0).red <= x"00";
--			pictures(1).red <= x"00";
--			pictures(0).green <= x"00";
--			pictures(1).green <= x"00";
--			pictures(0).blue <= FbRdDatap0(4 downto 0)&"000";
--			pictures(1).blue <= FbRdDatap3(4 downto 0)&"000";
		else
			hdr_image_o <= hdr_image;
		end if;
	end process;
	
		--pictures(0).red <= FbRdDatap0(15 downto 11)&"000";
		--pictures(0).green <= FbRdDatap0(10 downto 5)&"00";
		--pictures(0).blue <= FbRdDatap0(4 downto 0)&"000";
		--pictures(1).red <= FbRdDatap3(15 downto 11)&"000";
		--pictures(1).green <= FbRdDatap3(10 downto 5)&"00";
		--pictures(1).blue <= FbRdDatap3(4 downto 0)&"000";
		
	--pictures(0).red <= FbRdDatap0(15 downto 11)&"000";--wird nicht angezeigt
	--pictures(0).red <= x"00";
	--pictures(0).green <= FbRdDatap0(10 downto 5)&"00";--wird rot angezeigt
	--pictures(0).green <= x"00";
	--pictures(0).blue <= FbRdDatap0(4 downto 0)&"000";--wird blau angezeigt
	--pictures(0).blue <= x"00";
	
	--pictures(1).red <= FbRdDatap3(15 downto 11)&"000";
	--pictures(1).red <= x"00";
	--pictures(1).green <= FbRdDatap3(10 downto 5)&"00";
	--pictures(1).green <= x"00";
	--pictures(1).blue <= FbRdDatap3(4 downto 0)&"000";
	--pictures(1).blue <= x"00";
	
--	hdr_image.red <= x"00";
--	hdr_image.green <= FbRdDatap0(10 downto 5)&"00";
--	hdr_image.blue <= x"00";
	
	Inst_hdr_core : entity work.hdr_core_rgb
	port map(
		clk_i			=> clk_i,
		reset_i		=>	rst_i,
		
		pixel_i		=> pictures,
		pixel_o		=> hdr_image);

end Behavioral;

