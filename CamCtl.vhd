----------------------------------------------------------------------------------
-- Company: Digilent Ro
-- Engineer: Elod Gyorgy
-- 
-- Create Date:    16:34:19 04/21/2011 
-- Design Name: 
-- Module Name:    CamCtl - Behavioral 
-- Project Name: 	 VmodCAM Reference Design 2
-- Target Devices: Digilent VmodCAM with Aptina/Micron MT9D112 camera
-- Tool versions: 
-- Description: CamCtl configures an MT9D112 and provides a simple interface for
-- reading the video data. The configuration data set is easily modifiable to
-- suit a certain application. This specific configuration is for video capture
-- mode in 1600x1200 @ 80 MHz pixel clock.
--
-- Dependencies: 	digilent.TWIUtils
--						digilent.TWICtl
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.math_real.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;

library digilent;
use digilent.TWIUtils.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity CamCtl is
	Port(
		----------------------------------------------------------------------------------
		-- Camera Controller signals
		----------------------------------------------------------------------------------			 
		D_O     : out   STD_LOGIC_VECTOR(15 downto 0);
		PCLK_O  : out   STD_LOGIC;
		DV_O    : out   STD_LOGIC;
		RST_I   : in    STD_LOGIC;
		CLK     : in    STD_LOGIC;      --24 MHz
		CLK_180 : in    STD_LOGIC;

		--added by martin h
		SW_I : in std_logic_vector(6 downto 0);

		----------------------------------------------------------------------------------
		-- Camera signals
		----------------------------------------------------------------------------------			  
		SDA     : inout STD_LOGIC;
		SCL     : inout STD_LOGIC;
		D_I     : in    STD_LOGIC_VECTOR(7 downto 0);
		PCLK_I  : in    STD_LOGIC;
		MCLK_O  : out   STD_LOGIC;
		LV_I    : in    STD_LOGIC;
		FV_I    : in    STD_LOGIC;
		RST_O   : out   STD_LOGIC;      --Reset active LOW
		PWDN_O  : out   STD_LOGIC;      --Power-down active HIGH
		VDDEN_O : out   STD_LOGIC       --Power supply enable
	);
end CamCtl;

architecture Behavioral of CamCtl is
	attribute fsm_encoding : string;

	constant CLOCKFREQ : NATURAL := 24; --MHz

	constant TWI_MT9D112                 : std_logic_vector(7 downto 1) := "0111100";
	constant RST_T1_CYCLES               : NATURAL                      := 30; -- see MT9D112 datasheet
	constant RST_T4_CYCLES               : NATURAL                      := 7000; -- see MT9D112 datasheet
	constant IRD                         : std_logic                    := '1'; -- init read
	constant IWR                         : std_logic                    := '0'; -- init write
	constant VMODCAM_RST_RISETIME        : NATURAL                      := 25; --us
	constant VMODCAM_RST_RISETIME_CYCLES : NATURAL                      := natural(ceil(real(VMODCAM_RST_RISETIME * CLOCKFREQ)));
	constant VMODCAM_VDD_FALLTIME        : NATURAL                      := 100; --ms
	constant VMODCAM_VDD_FALLTIME_CYCLES : NATURAL                      := natural(ceil(real(VMODCAM_VDD_FALLTIME * 1_000 * CLOCKFREQ)));
	constant VMODCAM_VDD_RISETIME        : NATURAL                      := 50; --us
	constant VMODCAM_VDD_RISETIME_CYCLES : NATURAL                      := natural(ceil(real(VMODCAM_VDD_RISETIME * CLOCKFREQ)));

	constant CMD_DELAY        : NATURAL := 1; --ms
	constant CMD_DELAY_CYCLES : NATURAL := natural(ceil(real(CMD_DELAY * 1000 * CLOCKFREQ)));

	--modify this to reflect the number of configuration words
	constant INIT_VECTORS : natural := 59;
	constant DATA_WIDTH   : integer := 33;
	constant ADDR_WIDTH   : natural := natural(ceil(log(real(INIT_VECTORS), 2.0)));

	signal hex_pad : std_logic_vector(3 downto 0);

	type CamInitRAM_type is array (0 to INIT_VECTORS - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal CamInitRAM : CamInitRAM_type := (
		IRD & x"30001580",              -- Chip version. Default 0x1580

		IWR & x"33860501",              -- MCU Reset
		IWR & x"33860500",              -- MCU Release from reset
		IWR & x"32140D85",              -- Slew rate control, PCLK 5, D 5

		IWR & x"341E8F0B",              -- PLL control; bypassed, powered down
		IWR & x"341C0250",              -- PLL dividers; M=80,N=2,fMCLK=fCLKIN*M/(N+1)/8=80MHz
		IWR & x"341E8F09",              -- PLL control; Power-up PLL; wait 1ms after this!
		IWR & x"341E8F08",              -- PLL control; Turn off bypass

		IWR & x"30700000",
		IWR & x"32020008",              -- Standby control; Wake up
		IWR & x"338C2797",              -- Output format; Context B shadow
		IWR & x"33900030",              -- RGB with BT656 codes
		IWR & x"338C272F",              -- Sensor Row Start Context B
		IWR & x"33900004",              -- 4
		IWR & x"338C2733",              -- Sensor Row End Context B
		IWR & x"339004BB",              -- 1211
		IWR & x"338C2731",              -- Sensor Column Start Context B
		IWR & x"33900004",              -- 4
		IWR & x"338C2735",              -- Sensor Column End Context B
		IWR & x"3390064B",              -- 1611
		IWR & x"338C2707",              -- Output width; Context B
		IWR & x"33900640",              -- 1600
		IWR & x"338C2709",              -- Output height; Context B
		IWR & x"339004B0",              -- 1200
		IWR & x"338C275F",              -- Crop X0; Context B
		IWR & x"33900000",              -- 0
		IWR & x"338C2763",              -- Crop Y0; Context B
		IWR & x"33900000",              -- 0
		IWR & x"338C2761",              -- Crop X1; Context B
		IWR & x"33900640",              -- 1600
		IWR & x"338C2765",              -- Crop Y1; Context B
		IWR & x"339004B0",              -- 1200
		IWR & x"338C2741",              -- Sensor_Fine_IT_min B
		--IWR & x"33900169", -- 361 	
		IWR & x"33900000",              -- 0

		IWR & x"338CA120",              -- Capture mode options
		--IWR & x"339000F2", -- Turn on AWB, AE, HG, Video
		IWR & x"339000E2",              --manual Exposure
		IWR & x"33900002",              --manual Exposure all off 

		--IWR & x"338CA20D",--minVirtGain
		--IWR & x"3390" & minVirtGain,


		--IWR & x"338C2218", --status on/off over exp compensation
		--IWR & x"33900004",-- over exp off

		IWR & x"338CA103",              -- Refresh Sequencer Mode
		IWR & x"33900002",              -- Capture
		IRD & x"33900000",              -- Read until sequencer in mode 0 (run)
		IWR & x"301A02CC",              -- reset/output control; parallel enable, drive pins, start streaming
		IWR & x"338C2220",              --sequencer mode
		IWR & x"33900002",
		IWR & x"338CA120",              --capture mode options
		IWR & x"339000E2",              --manual Exposure
		--IWR & x"33900002",              --manual Exposure all off 
		IWR & x"32DC0080",              --digital gain for all colors def val.
		IWR & x"30280008",              --analogue gain global code default val.
		IWR & x"338C221A",              --R12 shutter delay
		IWR & x"33900408",              --shutter delay time def value
		IWR & x"338C2223",              --R9
		IWR & x"33900000",              --R9 def value
		IWR & x"338C2225",              --R65 ADC variable
		IWR & x"3390090B",              --R65 def val
		IWR & x"338CA229",              --gainR12 variable
		IWR & x"33900080",              --gainR12 def val
		IWR & x"338C222E",              --R9_step
		IWR & x"3390009D",              --R9_step def val
		IWR & x"301200FF",              --coarse integration time
		IWR & x"3012009D"
	);

	signal expos : std_logic_vector(15 downto 0) := x"005D";
	signal initWord, initFb : std_logic_vector(DATA_WIDTH - 1 downto 0);
	signal initA            : natural range 0 to INIT_VECTORS := 0;
	signal initEn, initFbWe : std_logic;
	--	attribute KEEP : string; 
	--	attribute KEEP of initWord     : signal is "TRUE";
	--	attribute KEEP of initFb     : signal is "TRUE";

	--coarse integration time
	signal itime   : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
	signal itimeEn : std_logic                                 := '0'; -- start control integration time when '1'

	type state_type is (stRegAddr1, stRegAddr2, stData1, stData2, stError, stDone, stIdle, stDelay);
	signal state, nstate : state_type := stIdle;

	signal twiStb, twiDone, twiErr, twiRst, iTwiStb, twiNewMsg : std_logic;
	signal twiAddr, twiDi, twiDo, iTwiData, iTwiAddr, regData1 : std_logic_vector(7 downto 0);
	signal twiErrType                                          : digilent.TWIUtils.error_type;

	signal waitCnt   : natural range 0 to CMD_DELAY_CYCLES := CMD_DELAY_CYCLES;
	signal waitCntEn : std_logic;

	signal rstCnt       : natural range 0 to RST_T1_CYCLES + RST_T4_CYCLES + 2 * VMODCAM_RST_RISETIME_CYCLES + VMODCAM_VDD_FALLTIME_CYCLES + VMODCAM_VDD_RISETIME_CYCLES := 0;
	signal intRst, SRst : std_logic                                                                                                                                      := '1';

	signal cam_data_sel : std_logic := '0';
	signal PClk_BUFG    : std_logic;
begin
	PWDN_O <= '0';                      --power up
	
	exp_change : process(sw_i, expos)
	begin
		case sw_i is
			when "0000000" => expos <= x"0000";
			when "0000001" => expos <= x"009D";
			when "0000010" => expos <= x"013A";
			when "0000011" => expos <= x"01D7";
			when "0000100" => expos <= x"0274";
			when "0000101" => expos <= x"0311";
			when "0000110" => expos <= x"03AE";
			when "0000111" => expos <= x"044B";
			when "0001000" => expos <= x"04E8";
			when "0001001" => expos <= x"0585";
			when "0001010" => expos <= x"0622";
			when "0001011" => expos <= x"06BF";
			when "0001100" => expos <= x"075C";
			when "0001101" => expos <= x"07F9";
			when "0001111" => expos <= x"0896";
			when others => expos <= x"0000";
		end case;
		
	end process exp_change;
	
	--itime <= IWR & x"3012FFFF";         --x"338C0000";
	itime <= IWR & x"3012" & expos(15 downto 0); --added by Martin

	BUFG_inst : BUFG
		port map(
			O => PClk_BUFG,             -- 1-bit Clock buffer output
			I => PCLK_I                 -- 1-bit Clock buffer input
		);

	PCLK_O <= PClk_BUFG;

	----------------------------------------------------------------------------------
	-- Local Reset
	----------------------------------------------------------------------------------
	Inst_LocalRst : entity digilent.LocalRst PORT MAP(
			RST_I  => RST_I,
			CLK_I  => CLK,
			SRST_O => SRst
		);

	----------------------------------------------------------------------------------
	-- MT9D112 Reset logic
	----------------------------------------------------------------------------------		
	RST_REG : process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (SRst = '1') then
				RST_O  <= '0';          -- reset MT9D112
				intRst <= '1';          -- reset this controller
				rstCnt <= 0;
			else
				if (rstCnt = RST_T1_CYCLES + VMODCAM_RST_RISETIME_CYCLES) then
					VDDEN_O <= '0';     -- after reset, we do a power cycle too
				elsif (rstCnt = RST_T1_CYCLES + VMODCAM_RST_RISETIME_CYCLES + VMODCAM_VDD_FALLTIME_CYCLES) then
					VDDEN_O <= '1';     -- turn on power
				elsif (rstCnt = RST_T1_CYCLES + VMODCAM_RST_RISETIME_CYCLES + VMODCAM_VDD_FALLTIME_CYCLES + VMODCAM_VDD_RISETIME_CYCLES) then
					RST_O <= '1';       -- we can release the MT9D112
				elsif (rstCnt = RST_T1_CYCLES + RST_T4_CYCLES + 2 * VMODCAM_RST_RISETIME_CYCLES + VMODCAM_VDD_FALLTIME_CYCLES + VMODCAM_VDD_RISETIME_CYCLES) then
					intRst <= '0';      -- we can release this controller too
				end if;

				if (rstCnt < RST_T1_CYCLES + RST_T4_CYCLES + 2 * VMODCAM_RST_RISETIME_CYCLES + VMODCAM_VDD_FALLTIME_CYCLES + VMODCAM_VDD_RISETIME_CYCLES) then
					rstCnt <= rstCnt + 1;
				end if;
			end if;
		end if;
	end process;

	Inst_ODDR2_MCLK_FORWARD : ODDR2
		generic map(
			DDR_ALIGNMENT => "NONE",    -- Sets output alignment to "NONE", "C0", "C1" 
			INIT          => '0',       -- Sets initial state of the Q output to '0' or '1'
			SRTYPE        => "SYNC")    -- Specifies "SYNC" or "ASYNC" set/reset
		port map(
			Q  => MCLK_O,               -- 1-bit output data
			C0 => CLK,                  -- 1-bit clock input
			C1 => CLK_180,              -- 1-bit clock input
			CE => '1',                  -- 1-bit clock enable input
			D0 => '0',                  -- 1-bit data input (associated with C0)
			D1 => '1',                  -- 1-bit data input (associated with C1)
			R  => '0',                  -- we don't forward clock to the camera until it's stable
			S  => '0'                   -- 1-bit set input
		);

	BYTESELMUX_PROC : process(PClk_BUFG, intRst)
	begin
		if (intRst = '1') then
			DV_O <= '0';
		elsif Rising_Edge(PClk_BUFG) then
			if (LV_I = '0') then
				cam_data_sel <= '0';
			else
				cam_data_sel <= not cam_data_sel;
			end if;

			if (cam_data_sel = '0') then
				DV_O <= '0';
			else
				DV_O <= '1';
			end if;
		end if;
	end process;

	INPUT_CAPTURE_PROC : process(PClk_BUFG)
	begin
		if Rising_Edge(PClk_BUFG) then
			if (cam_data_sel = '0') then
				D_O(15 downto 8) <= D_I;
			else
				D_O(7 downto 0) <= D_I;
			end if;
		end if;
	end process;

	Inst_TWICtl : entity digilent.TWICtl GENERIC MAP(CLOCKFREQ)
		PORT MAP(
			MSG_I     => twiNewMsg,
			STB_I     => twiStb,
			A_I       => twiAddr,
			D_I       => twiDi,
			D_O       => twiDo,
			DONE_O    => twiDone,
			ERR_O     => twiErr,
			ERRTYPE_O => twiErrType,
			CLK       => CLK,
			SRST      => intRst,
			SDA       => SDA,
			SCL       => SCL
		);

	twiAddr(7 downto 1) <= TWI_MT9D112;

	--Data might be read/written, Register Address is always written
	twiAddr(0) <= initWord(32) when state = stData1 or state = stData2 else '0';
	process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (initFbWe = '1') then
				CamInitRAM(initA) <= initFb;
			end if;
		end if;
	end process;

	initWord <= CamInitRAM(initA) when itimeEn = '0' else itime; --changed by Martin H.
	initFb   <= initWord(32 downto 0);  -- & regData1 & twiDo; --we feed read data back to the RAM

	Init_itimeEn : process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (SRst = '1') then
				itimeEn <= '0';
			elsif (initA = INIT_VECTORS and state = stDone) then
				itimeEn <= '1';
			end if;
		end if;
	end process;

	InitA_CNT : process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (state = stIdle or initA = INIT_VECTORS) then
				initA <= 0;
			elsif (initEn = '1') then
				initA <= initA + 1;
			end if;
		end if;
	end process;

	Wait_CNT : process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (waitCntEn = '0') then
				waitCnt <= CMD_DELAY_CYCLES;
			else
				waitCnt <= waitCnt - 1;
			end if;
		end if;
	end process;

	READBACK_PROC : process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (state = stData1 and twiDone = '1' and twiErr /= '1') then
				regData1 <= twiDo;
			end if;
		end if;
	end process;

	SYNC_PROC : process(CLK)
	begin
		if Rising_Edge(CLK) then
			if (intRst = '1') then
				state <= stIdle;
			else
				state <= nstate;
			end if;
		end if;
	end process;

	OUTPUT_DECODE : process(state, twiDone, twiErr, initWord)
	begin
		twiDi     <= "--------";
		twiStb    <= '0';
		twiNewMsg <= '0';
		case (state) is
			when stRegAddr1 =>
				twiDi     <= initWord(31 downto 24);
				twiStb    <= '1';
				twiNewMsg <= '1';
			when stRegAddr2 =>
				twiDi  <= initWord(23 downto 16);
				twiStb <= '1';
			when stData1 =>
				if (initWord(32) = '1') then
					twiNewMsg <= '1';
				end if;
				twiDi  <= initWord(15 downto 8);
				twiStb <= '1';
			when stData2 =>
				twiDi  <= initWord(7 downto 0);
				twiStb <= '1';
			when others =>
		--default values specifiec before case
		end case;

		initEn   <= '0';
		initFbWe <= '0';
		if (state = stData2 and twiDone = '1' and twiErr /= '1') then
			if (initWord(32) = IWR or (initWord(15 downto 8) = regData1 and initWord(7 downto 0) = twiDo)) then
				initEn <= '1';
			--				if (initWord(32) = IRD) then
			--					initFbWe <= '1';
			--				end if;
			end if;
		end if;
		if (state = stDone) then        -- readback phase, no TWI transfer takes place
			initEn <= '1';
		end if;

		waitCntEn <= '0';
		if (state = stDelay) then
			waitCntEn <= '1';
		end if;

	end process;

	NEXT_STATE_DECODE : process(state, twiDone, twiErr, initA, waitCnt)
	begin
		nstate <= state;                --default is to stay in current state
		case (state) is
			when stIdle =>
				nstate <= stRegAddr1;

			when stRegAddr1 =>
				if (twiDone = '1') then
					if (twiErr = '1') then
						nstate <= stError;
					else
						nstate <= stRegAddr2;
					end if;
				end if;
			when stRegAddr2 =>
				if (twiDone = '1') then
					if (twiErr = '1') then
						nstate <= stError;
					else
						nstate <= stData1;
					end if;
				end if;
			when stData1 =>
				if (twiDone = '1') then
					if (twiErr = '1') then
						nstate <= stError;
					else
						nstate <= stData2;
					end if;
				end if;
			when stData2 =>
				if (twiDone = '1') then
					if (twiErr = '1') then
						nstate <= stError;
					elsif (initA = INIT_VECTORS - 1) then
						nstate <= stDone;
					else
						nstate <= stDelay;
					end if;
				end if;
			when stDelay =>
				if (waitCnt = 0) then
					nstate <= stRegAddr1;
				end if;
			when stError =>
				nstate <= stRegAddr1;
			when stDone =>
				--stay here
				if (itimeEn = '1') then --added by M. Heide
					nstate <= stIdle;
				end if;
			when others =>
				nstate <= stIdle;
		end case;
	end process;

end Behavioral;

