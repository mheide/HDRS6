----------------------------------------------------------------------------------
-- Company: Digilent Ro
-- Engineer: Elod Gyorgy
-- 
-- Create Date:    12:50:18 04/21/2011 
-- Design Name:		VmodCAM Reference Design 2
-- Module Name:    	VmodCAM_Ref - Behavioral
-- Project Name: 		
-- Target Devices: 
-- Tool versions: 
-- Description: The design shows off the video feed from two cameras located on
-- a VmodCAM add-on board connected to an Atlys. The video feeds are displayed on
-- a DVI-capable flat panel at 1600x900@60Hz resolution. Each of the video feeds
-- is written to a frame buffer port to different locations in the RAM. Switch 7
-- can change the display from one feed to the other.
--
-- Dependencies:
-- digilent VHDL library (Video, VideoTimingCtl, TWICtl, TMDSEncoder,
-- DVITransmitter, SerializerN_1...)
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
use ieee_proposed.fixed_pkg.all;        -- ieee_proposed for compatibility version

-- Global Settings
use work.hdr_pkg.ALL;

-- LUTs
use work.inverse_pkg.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity VmodCAM_Ref is
	Generic(
		C3_NUM_DQ_PINS        : integer := 16;
		C3_MEM_ADDR_WIDTH     : integer := 13;
		C3_MEM_BANKADDR_WIDTH : integer := 3
	);
	Port(
		--Adept IO
		EppAstb          : in    std_logic;
		EppDstb          : in    std_logic;
		EppDB            : inout std_logic_vector(7 downto 0);
		EppWait          : out   std_logic;
		UsbWr            : out   std_logic;
		TMDS_TX_2_P      : out   STD_LOGIC;
		TMDS_TX_2_N      : out   STD_LOGIC;
		TMDS_TX_1_P      : out   STD_LOGIC;
		TMDS_TX_1_N      : out   STD_LOGIC;
		TMDS_TX_0_P      : out   STD_LOGIC;
		TMDS_TX_0_N      : out   STD_LOGIC;
		TMDS_TX_CLK_P    : out   STD_LOGIC;
		TMDS_TX_CLK_N    : out   STD_LOGIC;
		TMDS_TX_SCL      : inout STD_LOGIC;
		TMDS_TX_SDA      : inout STD_LOGIC;
		SW_I             : in    STD_LOGIC_VECTOR(7 downto 0);
		--LED_O : out STD_LOGIC_VECTOR(7 downto 0);
		CLK_I            : in    STD_LOGIC;
		RESET_I          : in    STD_LOGIC;
		----------------------------------------------------------------------------------
		-- Camera Board signals
		----------------------------------------------------------------------------------
		CAMA_SDA         : inout STD_LOGIC;
		CAMA_SCL         : inout STD_LOGIC;
		CAMA_D_I         : inout STD_LOGIC_VECTOR(7 downto 0); -- inout Workaround for IN_TERM bug AR# 	40818
		CAMA_PCLK_I      : inout STD_LOGIC; -- inout Workaround for IN_TERM bug AR# 	40818
		CAMA_MCLK_O      : out   STD_LOGIC;
		CAMA_LV_I        : inout STD_LOGIC; -- inout Workaround for IN_TERM bug AR# 	40818
		CAMA_FV_I        : inout STD_LOGIC; -- inout Workaround for IN_TERM bug AR# 	40818
		CAMA_RST_O       : out   STD_LOGIC; --Reset active LOW
		CAMA_PWDN_O      : out   STD_LOGIC; --Power-down active HIGH

		CAMX_VDDEN_O     : out   STD_LOGIC; -- common power supply enable (can do power cycle)

		CAMB_SDA         : inout STD_LOGIC;
		CAMB_SCL         : inout STD_LOGIC;
		CAMB_D_I         : inout STD_LOGIC_VECTOR(7 downto 0); -- inout Workaround for IN_TERM bug AR# 	40818
		CAMB_PCLK_I      : inout STD_LOGIC; -- inout Workaround for IN_TERM bug AR# 	40818
		CAMB_MCLK_O      : out   STD_LOGIC;
		CAMB_LV_I        : inout STD_LOGIC; -- inout Workaround for IN_TERM bug AR# 	40818
		CAMB_FV_I        : inout STD_LOGIC; -- inout Workaround for IN_TERM bug AR# 	40818
		CAMB_RST_O       : out   STD_LOGIC; --Reset active LOW
		CAMB_PWDN_O      : out   STD_LOGIC; --Power-down active HIGH			  
		----------------------------------------------------------------------------------
		-- DDR2 Interface
		----------------------------------------------------------------------------------
		mcb3_dram_dq     : inout std_logic_vector(C3_NUM_DQ_PINS - 1 downto 0);
		mcb3_dram_a      : out   std_logic_vector(C3_MEM_ADDR_WIDTH - 1 downto 0);
		mcb3_dram_ba     : out   std_logic_vector(C3_MEM_BANKADDR_WIDTH - 1 downto 0);
		mcb3_dram_ras_n  : out   std_logic;
		mcb3_dram_cas_n  : out   std_logic;
		mcb3_dram_we_n   : out   std_logic;
		mcb3_dram_odt    : out   std_logic;
		mcb3_dram_cke    : out   std_logic;
		mcb3_dram_dm     : out   std_logic;
		mcb3_dram_udqs   : inout std_logic;
		mcb3_dram_udqs_n : inout std_logic;
		mcb3_rzq         : inout std_logic;
		mcb3_zio         : inout std_logic;
		mcb3_dram_udm    : out   std_logic;
		mcb3_dram_dqs    : inout std_logic;
		mcb3_dram_dqs_n  : inout std_logic;
		mcb3_dram_ck     : out   std_logic;
		mcb3_dram_ck_n   : out   std_logic
	);
end VmodCAM_Ref;

architecture Behavioral of VmodCAM_Ref is
	signal SysClk, PClk, PClkX2, SysRst, SerClk, SerStb : std_logic;
	signal MSel                                         : std_logic_vector(0 downto 0);

	signal VtcHs, VtcVs, VtcVde, VtcRst : std_logic;
	signal VtcHCnt, VtcVCnt             : NATURAL;

	signal CamClk, CamClk_180, CamAPClk, CamBPClk, CamADV, CamBDV, CamAVddEn, CamBVddEn                          : std_logic;
	signal CamAD, CamBD                                                                                          : std_logic_vector(15 downto 0);
	signal dummy_t, int_CAMA_PCLK_I, int_CAMA_FV_I, int_CAMA_LV_I, int_CAMB_PCLK_I, int_CAMB_FV_I, int_CAMB_LV_I : std_logic;
	signal int_CAMA_D_I, int_CAMB_D_I                                                                            : std_logic_vector(7 downto 0);

	attribute S : string;
	attribute S of CAMA_PCLK_I : signal is "TRUE";
	attribute S of CAMA_FV_I : signal is "TRUE";
	attribute S of CAMA_LV_I : signal is "TRUE";
	attribute S of CAMA_D_I : signal is "TRUE";
	attribute S of CAMB_PCLK_I : signal is "TRUE";
	attribute S of CAMB_FV_I : signal is "TRUE";
	attribute S of CAMB_LV_I : signal is "TRUE";
	attribute S of CAMB_D_I : signal is "TRUE";
	attribute S of dummy_t : signal is "TRUE";

	signal ddr2clk_2x, ddr2clk_2x_180, mcb_drp_clk, pll_ce_0, pll_ce_90, pll_lock, async_rst : std_logic;
	signal FbRdy, FbRdEn, FbRdRst, FbRdClk                                                   : std_logic;
	signal FbRdData                                                                          : std_logic_vector(16 - 1 downto 0);
	signal FbRdDatap0                                                                        : std_logic_vector(16 - 1 downto 0); --added by Martin Heide
	signal FbRdDatap3                                                                        : std_logic_vector(16 - 1 downto 0); --added by Martin Heide
	signal FbWrARst, FbWrBRst, int_FVA, int_FVB                                              : std_logic;

	signal hdr_image : pixel_type;

begin

	--LED_O <= VtcHs & VtcHs & VtcVde & async_rst & MSel(0) & "000";

	----------------------------------------------------------------------------------
	-- System Control Unit
	-- This component provides a System Clock, a Synchronous Reset and other signals
	-- needed for the 40:4 serialization:
	--	- Serialization clock (5x System Clock)
	-- - Serialization strobe
	-- - 2x Pixel Clock
	----------------------------------------------------------------------------------
	Inst_SysCon : entity work.SysCon PORT MAP(
			CLK_I            => CLK_I,
			CLK_O            => open,
			RSTN_I           => RESET_I,
			SW_I             => SW_I,   --changed by Martin Heide
			SW_O             => open,
			RSEL_O           => open,   --resolution selector synchronized with PClk
			MSEL_O           => MSel,   --mode selector synchronized with PClk
			CAMCLK_O         => CamClk,
			CAMCLK_180_O     => CamClk_180,
			PCLK_O           => PClk,
			PCLK_X2_O        => PClkX2,
			PCLK_X10_O       => SerClk,
			SERDESSTROBE_O   => SerStb,
			DDR2CLK_2X_O     => DDR2Clk_2x,
			DDR2CLK_2X_180_O => DDR2Clk_2x_180,
			MCB_DRP_CLK_O    => mcb_drp_clk,
			PLL_CE_0_O       => pll_ce_0,
			PLL_CE_90_O      => pll_ce_90,
			PLL_LOCK         => pll_lock,
			ASYNC_RST        => async_rst
		);

	----------------------------------------------------------------------------------
	-- Video Timing Controller
	-- Generates horizontal and vertical sync and video data enable signals.
	----------------------------------------------------------------------------------
	Inst_VideoTimingCtl : entity digilent.VideoTimingCtl PORT MAP(
			PCLK_I => PClk,
			RSEL_I => R1600_900P,       --this project supports only 1600x900
			RST_I  => VtcRst,
			VDE_O  => VtcVde,
			HS_O   => VtcHs,
			VS_O   => VtcVs,
			HCNT_O => VtcHCnt,
			VCNT_O => VtcVCnt
		);
	VtcRst <= async_rst or not FbRdy;
	----------------------------------------------------------------------------------
	-- Frame Buffer
	----------------------------------------------------------------------------------
	Inst_FBCtl : entity work.FBCtl
		GENERIC MAP(
			DEBUG_EN   => 0,
			COLORDEPTH => 16
		)
		PORT MAP(
			RDY_O            => FbRdy,
			ENC              => FbRdEn,
			RSTC_I           => FbRdRst,
			DOC              => FbRdDatap3,
			DOCp0            => FbRdDatap0, --added by Martin Heide
			CLKC             => FbRdClk,
			--RD_MODE => MSel,

			RD_MODE          => "00000000", --changed by Martin Heide
			ENA              => CamADV,
			RSTA_I           => FbWrARst,
			DIA              => CamAD,
			CLKA             => CamAPClk,
			ENB              => CamBDV,
			RSTB_I           => FbWrBRst,
			DIB              => CamBD,
			CLKB             => CamBPClk,
			ddr2clk_2x       => DDR2Clk_2x,
			ddr2clk_2x_180   => DDR2Clk_2x_180,
			pll_ce_0         => pll_ce_0,
			pll_ce_90        => pll_ce_90,
			pll_lock         => pll_lock,
			async_rst        => async_rst,
			mcb_drp_clk      => mcb_drp_clk,
			mcb3_dram_dq     => mcb3_dram_dq,
			mcb3_dram_a      => mcb3_dram_a,
			mcb3_dram_ba     => mcb3_dram_ba,
			mcb3_dram_ras_n  => mcb3_dram_ras_n,
			mcb3_dram_cas_n  => mcb3_dram_cas_n,
			mcb3_dram_we_n   => mcb3_dram_we_n,
			mcb3_dram_odt    => mcb3_dram_odt,
			mcb3_dram_cke    => mcb3_dram_cke,
			mcb3_dram_dm     => mcb3_dram_dm,
			mcb3_dram_udqs   => mcb3_dram_udqs,
			mcb3_dram_udqs_n => mcb3_dram_udqs_n,
			mcb3_rzq         => mcb3_rzq,
			mcb3_zio         => mcb3_zio,
			mcb3_dram_udm    => mcb3_dram_udm,
			mcb3_dram_dqs    => mcb3_dram_dqs,
			mcb3_dram_dqs_n  => mcb3_dram_dqs_n,
			mcb3_dram_ck     => mcb3_dram_ck,
			mcb3_dram_ck_n   => mcb3_dram_ck_n
		);

	FbRdEn  <= VtcVde;
	FbRdRst <= async_rst;
	FbRdClk <= PClk;
	--Register FV signal to meet timing for FbWrXRst
	Inst_InputSync_FVA : entity digilent.InputSync PORT MAP(
			D_I   => int_CAMA_FV_I,
			D_O   => int_FVA,
			CLK_I => CamAPClk
		);
	Inst_InputSync_FVB : entity digilent.InputSync PORT MAP(
			D_I   => int_CAMB_FV_I,
			D_O   => int_FVB,
			CLK_I => CamBPClk
		);

	FbWrARst <= async_rst or not int_FVA;
	FbWrBRst <= async_rst or not int_FVB;

	----------------------------------------------------------------------------------
	--Pixel Subtractor
	------------------------------------------------------------------------------------
	--  Inst_PSubtract : entity work.PSubtract
	--    Port map ( clk_i => FbRdClk,
	--           rst_i => async_rst, --async reset
	--           sw_i => SW_I,
	--           padata_i => FbRdDatap0,
	--           pbdata_i => FbRdDatap3,
	--           padata_o => FbRdData,
	--           pbdata_o => open
	--			   );

	----------------------------------------------------------------------------------
	-- DVI Transmitter
	----------------------------------------------------------------------------------
	Inst_DVITransmitter : entity digilent.DVITransmitter PORT MAP(
			RED_I         => hdr_image.red, --FbRdData(15 downto 11) & "000",
			GREEN_I       => hdr_image.green, --FbRdData(10 downto 5) & "00",
			BLUE_I        => hdr_image.blue, --FbRdData(4 downto 0) & "000",
			HS_I          => VtcHs,
			VS_I          => VtcVs,
			VDE_I         => VtcVde,
			PCLK_I        => PClk,
			PCLK_X2_I     => PClkX2,
			SERCLK_I      => SerClk,
			SERSTB_I      => SerStb,
			TMDS_TX_2_P   => TMDS_TX_2_P,
			TMDS_TX_2_N   => TMDS_TX_2_N,
			TMDS_TX_1_P   => TMDS_TX_1_P,
			TMDS_TX_1_N   => TMDS_TX_1_N,
			TMDS_TX_0_P   => TMDS_TX_0_P,
			TMDS_TX_0_N   => TMDS_TX_0_N,
			TMDS_TX_CLK_P => TMDS_TX_CLK_P,
			TMDS_TX_CLK_N => TMDS_TX_CLK_N
		);

	----------------------------------------------------------------------------------
	-- Camera A Controller
	----------------------------------------------------------------------------------
	Inst_camctlA : entity work.camctl
		PORT MAP(
			D_O     => CamAD,
			PCLK_O  => CamAPClk,
			DV_O    => CamADV,
			RST_I   => async_rst,
			CLK     => CamClk,
			CLK_180 => CamClk_180,
			SW_I    => SW_I(6 downto 0),
			SDA     => CAMA_SDA,
			SCL     => CAMA_SCL,
			D_I     => int_CAMA_D_I,
			PCLK_I  => int_CAMA_PCLK_I,
			MCLK_O  => CAMA_MCLK_O,
			LV_I    => int_CAMA_LV_I,
			FV_I    => int_CAMA_FV_I,
			RST_O   => CAMA_RST_O,
			PWDN_O  => CAMA_PWDN_O,
			VDDEN_O => CamAVddEn
		);
	----------------------------------------------------------------------------------
	-- Camera B Controller
	----------------------------------------------------------------------------------
	Inst_camctlB : entity work.camctlsdr
		PORT MAP(
			eppAstb_i => EppAstb,
			eppDstb_i => EppDstb,
			eppDB_io  => EppDB,
			eppWait_o => EppWait,
			eppWr_o   => UsbWr,
			sw_i      => SW_i(6),
			D_O       => CamBD,
			PCLK_O    => CamBPClk,
			DV_O      => CamBDV,
			RST_I     => async_rst,
			CLK       => CamClk,
			CLK_180   => CamClk_180,
			SDA       => CAMB_SDA,
			SCL       => CAMB_SCL,
			D_I       => int_CAMB_D_I,
			PCLK_I    => int_CAMB_PCLK_I,
			MCLK_O    => CAMB_MCLK_O,
			LV_I      => int_CAMB_LV_I,
			FV_I      => int_CAMB_FV_I,
			RST_O     => CAMB_RST_O,
			PWDN_O    => CAMB_PWDN_O,
			VDDEN_O   => CamBVddEn
		);
	CAMX_VDDEN_O <= CamAVddEn and CamBVddEn;

	----------------------------------------------------------------------------------
	--HDR - Core
	----------------------------------------------------------------------------------
	Inst_HDR_wrapper : entity work.HDR_wrapper
		Port map(clk_i       => FbRdClk,
			     rst_i       => async_rst,
			     sw_i        => SW_I(7),
			     FbRdDatap0  => FbRdDatap0,
			     FbRdDatap3  => FbRdDatap3,
			     hdr_image_o => hdr_image);

	----------------------------------------------------------------------------------
	-- Workaround for IN_TERM bug AR# 	40818
	----------------------------------------------------------------------------------
	Inst_IOBUF_CAMA_PCLK : IOBUF
		generic map(
			DRIVE      => 12,
			IOSTANDARD => "DEFAULT",
			SLEW       => "SLOW")
		port map(
			O  => int_CAMA_PCLK_I,      -- Buffer output
			IO => CAMA_PCLK_I,          -- Buffer inout port (connect directly to top-level port)
			I  => '0',                  -- Buffer input
			T  => dummy_t               -- 3-state enable input, high=input, low=output 

		);
	Inst_IOBUF_CAMA_FV : IOBUF
		generic map(
			DRIVE      => 12,
			IOSTANDARD => "DEFAULT",
			SLEW       => "SLOW")
		port map(
			O  => int_CAMA_FV_I,        -- Buffer output
			IO => CAMA_FV_I,            -- Buffer inout port (connect directly to top-level port)
			I  => '0',                  -- Buffer input
			T  => dummy_t               -- 3-state enable input, high=input, low=output 

		);
	Inst_IOBUF_CAMA_LV : IOBUF
		generic map(
			DRIVE      => 12,
			IOSTANDARD => "DEFAULT",
			SLEW       => "SLOW")
		port map(
			O  => int_CAMA_LV_I,        -- Buffer output
			IO => CAMA_LV_I,            -- Buffer inout port (connect directly to top-level port)
			I  => '0',                  -- Buffer input
			T  => dummy_t               -- 3-state enable input, high=input, low=output 

		);
	Gen_IOBUF_CAMA_D : for i in 7 downto 0 generate
		Inst_IOBUF_CAMA_D : IOBUF
			generic map(
				DRIVE      => 12,
				IOSTANDARD => "DEFAULT",
				SLEW       => "SLOW")
			port map(
				O  => int_CAMA_D_I(i),  -- Buffer output
				IO => CAMA_D_I(i),      -- Buffer inout port (connect directly to top-level port)
				I  => '0',              -- Buffer input
				T  => dummy_t           -- 3-state enable input, high=input, low=output 

			);
	end generate;

	Inst_IOBUF_CAMB_PCLK : IOBUF
		generic map(
			DRIVE      => 12,
			IOSTANDARD => "DEFAULT",
			SLEW       => "SLOW")
		port map(
			O  => int_CAMB_PCLK_I,      -- Buffer output
			IO => CAMB_PCLK_I,          -- Buffer inout port (connect directly to top-level port)
			I  => '0',                  -- Buffer input
			T  => dummy_t               -- 3-state enable input, high=input, low=output 

		);
	Inst_IOBUF_CAMB_FV : IOBUF
		generic map(
			DRIVE      => 12,
			IOSTANDARD => "DEFAULT",
			SLEW       => "SLOW")
		port map(
			O  => int_CAMB_FV_I,        -- Buffer output
			IO => CAMB_FV_I,            -- Buffer inout port (connect directly to top-level port)
			I  => '0',                  -- Buffer input
			T  => dummy_t               -- 3-state enable input, high=input, low=output 

		);
	Inst_IOBUF_CAMB_LV : IOBUF
		generic map(
			DRIVE      => 12,
			IOSTANDARD => "DEFAULT",
			SLEW       => "SLOW")
		port map(
			O  => int_CAMB_LV_I,        -- Buffer output
			IO => CAMB_LV_I,            -- Buffer inout port (connect directly to top-level port)
			I  => '0',                  -- Buffer input
			T  => dummy_t               -- 3-state enable input, high=input, low=output 

		);
	Gen_IOBUF_CAMB_D : for i in 7 downto 0 generate
		Inst_IOBUF_CAMB_D : IOBUF
			generic map(
				DRIVE      => 12,
				IOSTANDARD => "DEFAULT",
				SLEW       => "SLOW")
			port map(
				O  => int_CAMB_D_I(i),  -- Buffer output
				IO => CAMB_D_I(i),      -- Buffer inout port (connect directly to top-level port)
				I  => '0',              -- Buffer input
				T  => dummy_t           -- 3-state enable input, high=input, low=output 

			);
	end generate;
	dummy_t <= '1';
end Behavioral;

