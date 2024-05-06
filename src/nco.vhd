

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY nco IS 
	GENERIC (
		NCO_W 			: NATURAL := 32;
		DSP_SLICE 		: BOOLEAN := False
	);
	PORT (
		clk 			: IN  std_logic;
		init 			: IN  std_logic;

		freq_word 		: IN  std_logic_vector(NCO_W -1 DOWNTO 0);
		freq_adjust 	: IN  std_logic_vector(NCO_W -1 DOWNTO 0);

		phase    		: OUT std_logic_vector(NCO_W -1 DOWNTO 0);
		rollover_pi2 	: OUT std_logic;
		rollover_pi 	: OUT std_logic;
		rollover_3pi2 	: OUT std_logic;
		rollover_2pi 	: OUT std_logic;
		tclk_even		: OUT std_logic;
		tclk_odd 		: OUT std_logic
	);
END ENTITY nco;

ARCHITECTURE rtl OF nco IS 

	SIGNAL phase_sum 				: unsigned(NCO_W -1 DOWNTO 0);
	SIGNAL phase_acc 				: unsigned(NCO_W -1 DOWNTO 0);
	SIGNAL phase_acc_msbs 			: std_logic_vector(1 DOWNTO 0); 
	SIGNAL phase_delta_adjusted 	: unsigned(NCO_W -1 DOWNTO 0);

BEGIN

	NO_DSP_GEN : IF DSP_SLICE = False GENERATE

		phase_sum 	<= phase_acc + phase_delta_adjusted;
		phase 		<= std_logic_vector(phase_acc);

		phase_proc : PROCESS (clk)
			VARIABLE v_phase_acc_msbs : std_logic_vector(1 DOWNTO 0);
		BEGIN
			IF clk'EVENT AND clk = '1' THEN
				IF init = '1' THEN
					phase_delta_adjusted <= (OTHERS => '0');
					phase_acc 			 <= (OTHERS => '0');
					phase_acc_msbs 		 <= (OTHERS => '1');
					rollover_pi2 		 <= '0';
					rollover_pi 		 <= '0';
					rollover_3pi2 	 	 <= '0';
					rollover_2pi		 <= '1';
				ELSE

					phase_delta_adjusted <= unsigned(signed(freq_word) + signed(freq_adjust));
					phase_acc  			 <= phase_sum;
					phase_acc_msbs 		 <= std_logic_vector(phase_sum(NCO_W -1 DOWNTO NCO_W -2));
					v_phase_acc_msbs 	 := std_logic_vector(phase_sum(NCO_W -1 DOWNTO NCO_W -2));

					rollover_pi2 		 <= '0';
					rollover_pi 		 <= '0';
					rollover_3pi2 	 	 <= '0';
					rollover_2pi		 <= '0';

					tclk_even			 <= '0';
					tclk_odd 			 <= '0';

					IF phase_acc_msbs = "11" AND v_phase_acc_msbs = "00" THEN
						rollover_2pi	 <= '1';
						tclk_odd 	     <= '1';
					END IF;

					IF phase_acc_msbs = "00" AND v_phase_acc_msbs = "01" THEN
						rollover_pi2 	 <= '1';
						tclk_even 	     <= '1';
					END IF;

					IF phase_acc_msbs = "01" AND v_phase_acc_msbs = "10" THEN
						rollover_pi	 	 <= '1';
						tclk_odd 	     <= '1';
					END IF;

					IF phase_acc_msbs = "10" AND v_phase_acc_msbs = "11" THEN
						rollover_3pi2 	 <= '1';
						tclk_even 	     <= '1';
					END IF;

				END IF;
			END IF;
		END PROCESS phase_proc;

	END GENERATE NO_DSP_GEN;

	--DSP_GEN : IF DSP_SLICE GENERATE

	--	U_phase_accum : DSP48E1
	--	GENERIC MAP (
	--		-- Feature Control Attributes: Data Path Selection
	--		A_INPUT 			=> "DIRECT",		-- Selects A input source, "DIRECT" (A port) or "CASCADE" (ACIN port)
	--		B_INPUT 			=> "DIRECT",		-- Selects B input source, "DIRECT" (B port) or "CASCADE" (BCIN port)
	--		USE_DPORT 			=> True,			-- Select D port usage (TRUE or FALSE)
	--		USE_MULT 			=> "MULTIPLY",		-- Select multiplier usage ("MULTIPLY", "DYNAMIC", or "NONE")
	--		-- Pattern Detector Attributes: Pattern Detection Configuration
	--		AUTORESET_PATDET 	=> "NO_RESET",		-- "NO_RESET", "RESET_MATCH", "RESET_NOT_MATCH"
	--		MASK 				=> X"3fffffffffff", -- 48-bit mask value for pattern detect (1=ignore)
	--		PATTERN 			=> X"000000000000",	-- 48-bit pattern match for pattern detect
	--		SEL_MASK 			=> "MASK",			-- "C", "MASK", "ROUNDING_MODE1", "ROUNDING_MODE2"
	--		SEL_PATTERN 		=> "PATTERN",		-- Select pattern value ("PATTERN" or "C")
	--		USE_PATTERN_DETECT 	=> "NO_PATDET", 	-- Enable pattern detect ("PATDET" or "NO_PATDET")
	--		-- Register Control Attributes: Pipeline Register Configuration
	--		ACASCREG 			=> 1,				-- Number of pipeline stages between A/ACIN and ACOUT (0, 1 or 2) 
	--		ADREG 				=> 1,				-- Number of pipeline stages for pre-adder (0 or 1)
	--		ALUMODEREG 			=> 1,				-- Number of pipeline stages for ALUMODE (0 or 1)
	--		AREG 				=> 1,				-- Number of pipeline stages for A (0,1or 2)
	--		BCASCREG 			=> 1,				-- Number of pipeline stages between B/BCIN and BCOUT (0, 1 or 2)
	--		BREG 				=> 1,				-- Number of pipeline stages for B (0, 1 or 2)
	--		CARRYINREG 			=> 1,				-- Number of pipeline stages for CARRYIN (0 or 1)
	--		CARRYINSELREG 		=> 1,				-- Number of pipeline stages for CARRYINSEL (0 or 1)
	--		CREG 				=> 1,				-- Number of pipeline stages for C (0 or 1)
	--		DREG 				=> 1,				-- Number of pipeline stages for D (0 or 1)
	--		INMODEREG 			=> 1,				-- Number of pipeline stages for INMODE (0 or 1)
	--		MREG 				=> 1,				-- Number of multiplier pipeline stages (0 or 1)
	--		OPMODEREG 			=> 1,				-- Number of pipeline stages for OPMODE (0 or 1)
	--		PREG 				=> 1,				-- Number of pipeline stages for P (0 or 1)
	--		USE_SIMD 			=> "ONE48"			-- SIMD selection ("ONE48", "TWO24", "FOUR12")
	--	)
	--	PORT MAP (
	--		-- Cascade: 30-bit (each) output: Cascade Ports
	--		ACOUT 				=> ACOUT,
	--		BCOUT 				=> BCOUT,
	--		CARRYCASCOUT 		=> CARRYCASCOUT,
	--		MULTSIGNOUT 		=> MULTSIGNOUT,
	--		PCOUT 				=> PCOUT,
	--		-- Control: 1-bit (each) output: Control Inputs/Status Bits
	--		OVERFLOW 			=> OVERFLOW,			-- 1-bit output: Overflow in add/acc output
	--		PATTERNBDETECT 		=> PATTERNBDETECT, 		-- 1-bit output: Pattern bar detect output
	--		PATTERNDETECT 		=> PATTERNDETECT,   	-- 1-bit output: Pattern detect output
	--		UNDERFLOW 			=> UNDERFLOW,           -- 1-bit output: Underflow in add/acc output
	--		-- Data: 4-bit (each) output: Data Ports
	--		CARRYOUT 			=> CARRYOUT,            -- 4-bit output: Carry output
	--		P 					=> P,					-- 48-bit output: Primary data output
	--		-- Cascade: 30-bit (each) input: Cascade Ports
	--		ACIN 				=> ACIN,
	--		BCIN 				=> BCIN,
	--		CARRYCASCIN 		=> CARRYCASCIN,
	--		MULTSIGNIN 			=> MULTSIGNIN,
	--		PCIN 				=> PCIN,
	--		-- Control: 4-bit (each) input: Control Inputs/Status Bits
    --       	ALUMODE 			=> ALUMODE,
    --       	CARRYINSEL 			=> CARRYINSEL,
    --       	CEINMODE 			=> CEINMODE,
    --       	CLK 				=> CLK,
    --       	INMODE 				=> INMODE,
    --       	OPMODE 				=> OPMODE,
	--		RSTINMODE			=> RSTINMODE,           -- 1-bit input: Reset input for INMODEREG
	--		-- Data: 30-bit (each) input: Data Ports
	--		A					=> A,					-- 30-bit input: A data input
	--		B					=> B,					-- 18-bit input: B data input
	--		C					=> C,					-- 48-bit input: C data input
	--		CARRYIN 			=> CARRYIN, 			-- 1-bit input: Carry input signal
	--		D 					=> D,					-- 25-bit input: D data input
	--		-- Reset/Clock Enable: 1-bit (each) input: Reset/Clock Enable Inputs
	--		CEA1 				=> CEA1,				-- 1-bit input: Clock enable input for 1st stage AREG
	--		CEA2 				=> CEA2,				-- 1-bit input: Clock enable input for 2nd stage AREG
	--		CEAD 				=> CEAD,				-- 1-bit input: Clock enable input for ADREG
	--		CEALUMODE 			=> CEALUMODE,			-- 1-bit input: Clock enable input for ALUMODERE
	--		CEB1 				=> CEB1,				-- 1-bit input: Clock enable input for 1st stage BREG
	--		CEB2 				=> CEB2,				-- 1-bit input: Clock enable input for 2nd stage BREG
	--		CEC 				=> CEC,					-- 1-bit input: Clock enable input for CREG
	--		CECARRYIN 			=> CECARRYIN,			-- 1-bit input: Clock enable input for CARRYINREG
	--		CECTRL 				=> CECTRL,				-- 1-bit input: Clock enable input for OPMODEREG and CARRYINSELREG
	--		CED 				=> CED,					-- 1-bit input: Clock enable input for DREG
	--		CEM 				=> CEM,					-- 1-bit input: Clock enable input for MREG
	--		CEP 				=> CEP,					-- 1-bit input: Clock enable input for PREG
	--		RSTA 				=> RSTA,				-- 1-bit input: Reset input for AREG
	--		RSTALLCARRYIN 		=> RSTALLCARRYIN,		-- 1-bit input: Reset input for CARRYINREG
	--		RSTALUMODE 			=> RSTALUMODE,			-- 1-bit input: Reset input for ALUMODEREG
	--		RSTB 				=> RSTB,				-- 1-bit input: Reset input for BREG
	--		RSTC 				=> RSTC,				-- 1-bit input: Reset input for CREG
	--		RSTCTRL 			=> RSTCTRL,				-- 1-bit input: Reset input for OPMODEREG and CARRYINSELREG
	--		RSTD 				=> RSTD,				-- 1-bit input: Reset input for DREG and ADREG
	--		RSTM 				=> RSTM,				-- 1-bit input: Reset input for MREG
	--		RSTP 				=> RSTP					-- 1-bit input: Reset input for PREG
	--	);

	--END GENERATE DSP_GEN;

END ARCHITECTURE rtl;

