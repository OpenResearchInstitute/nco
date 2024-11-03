------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
--  _______                             ________                                            ______
--  __  __ \________ _____ _______      ___  __ \_____ _____________ ______ ___________________  /_
--  _  / / /___  __ \_  _ \__  __ \     __  /_/ /_  _ \__  ___/_  _ \_  __ `/__  ___/_  ___/__  __ \
--  / /_/ / __  /_/ //  __/_  / / /     _  _, _/ /  __/_(__  ) /  __// /_/ / _  /    / /__  _  / / /
--  \____/  _  .___/ \___/ /_/ /_/      /_/ |_|  \___/ /____/  \___/ \__,_/  /_/     \___/  /_/ /_/
--          /_/
--                   ________                _____ _____ _____         _____
--                   ____  _/_______ __________  /____(_)__  /_____  ____  /______
--                    __  /  __  __ \__  ___/_  __/__  / _  __/_  / / /_  __/_  _ \
--                   __/ /   _  / / /_(__  ) / /_  _  /  / /_  / /_/ / / /_  /  __/
--                   /___/   /_/ /_/ /____/  \__/  /_/   \__/  \__,_/  \__/  \___/
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------
-- Copyright
------------------------------------------------------------------------------------------------------
--
-- Copyright 2024 by M. Wishek <matthew@wishek.com>
--
------------------------------------------------------------------------------------------------------
-- License
------------------------------------------------------------------------------------------------------
--
-- This source describes Open Hardware and is licensed under the CERN-OHL-W v2.
--
-- You may redistribute and modify this source and make products using it under
-- the terms of the CERN-OHL-W v2 (https://ohwr.org/cern_ohl_w_v2.txt).
--
-- This source is distributed WITHOUT ANY EXPRESS OR IMPLIED WARRANTY, INCLUDING
-- OF MERCHANTABILITY, SATISFACTORY QUALITY AND FITNESS FOR A PARTICULAR PURPOSE.
-- Please see the CERN-OHL-W v2 for applicable conditions.
--
-- Source location: TBD
--
-- As per CERN-OHL-W v2 section 4.1, should You produce hardware based on this
-- source, You must maintain the Source Location visible on the external case of
-- the products you make using this source.
--
------------------------------------------------------------------------------------------------------
-- Block name and description
------------------------------------------------------------------------------------------------------
--
-- This block provides an NCO for use in the MSK Modulator and Demodulator.
--
-- Documentation location: TBD
--
------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------
-- ╦  ┬┌┐ ┬─┐┌─┐┬─┐┬┌─┐┌─┐
-- ║  │├┴┐├┬┘├─┤├┬┘│├┤ └─┐
-- ╩═╝┴└─┘┴└─┴ ┴┴└─┴└─┘└─┘
------------------------------------------------------------------------------------------------------
-- Libraries

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;


------------------------------------------------------------------------------------------------------
-- ╔═╗┌┐┌┌┬┐┬┌┬┐┬ ┬
-- ║╣ │││ │ │ │ └┬┘
-- ╚═╝┘└┘ ┴ ┴ ┴  ┴ 
------------------------------------------------------------------------------------------------------
-- Entity

ENTITY nco IS 
	GENERIC (
		NCO_W 			: NATURAL := 32;
		PHASE_INIT 		: UNSIGNED(32 -1 DOWNTO 0) := (OTHERS => '0');
		DSP_SLICE 		: BOOLEAN := False
	);
	PORT (
		clk 			: IN  std_logic;
		init 			: IN  std_logic;

		enable 			: IN  std_logic;

		discard_nco 	: IN  std_logic_vector(7 DOWNTO 0);
		freq_word 		: IN  std_logic_vector(NCO_W -1 DOWNTO 0);

		freq_adj_zero 	: IN  std_logic;
		freq_adj_valid 	: IN  std_logic;
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


------------------------------------------------------------------------------------------------------
-- ╔═╗┬─┐┌─┐┬ ┬┬┌┬┐┌─┐┌─┐┌┬┐┬ ┬┬─┐┌─┐
-- ╠═╣├┬┘│  ├─┤│ │ ├┤ │   │ │ │├┬┘├┤ 
-- ╩ ╩┴└─└─┘┴ ┴┴ ┴ └─┘└─┘ ┴ └─┘┴└─└─┘
------------------------------------------------------------------------------------------------------
-- Architecture

ARCHITECTURE rtl OF nco IS 

	CONSTANT PHASE_MSBS_INIT 		: std_logic_vector(1 DOWNTO 0) := std_logic_vector(resize(shift_right(PHASE_INIT -1, 30), 2));

	SIGNAL phase_sum 				: unsigned(NCO_W -1 DOWNTO 0);
	SIGNAL phase_acc 				: unsigned(NCO_W -1 DOWNTO 0);
	SIGNAL phase_acc_msbs 			: std_logic_vector(1 DOWNTO 0); 
	SIGNAL phase_delta_adjusted 	: unsigned(NCO_W -1 DOWNTO 0);
	SIGNAL freq_adjust_q 			: std_logic_vector(NCO_W -1 DOWNTO 0);
	SIGNAL discard_count 			: unsigned(7 DOWNTO 0);

BEGIN

------------------------------------------------------------------------------------------------------
--  __             __  __         __  __                         ___  __   __  
-- |__) |__|  /\  (_  |_     /\  /   /   /  \ |\/| /  \ |    /\   |  /  \ |__) 
-- |    |  | /--\ __) |__   /--\ \__ \__ \__/ |  | \__/ |__ /--\  |  \__/ | \  
--                                                                             
------------------------------------------------------------------------------------------------------
-- Phase Accumulator

	NO_DSP_GEN : IF DSP_SLICE = False GENERATE

		phase_sum 	<= phase_acc + phase_delta_adjusted;

		phase_proc : PROCESS (clk)
			VARIABLE v_phase_acc_msbs : std_logic_vector(1 DOWNTO 0);
		BEGIN
			IF clk'EVENT AND clk = '1' THEN
				IF init = '1' THEN
					phase_delta_adjusted <= unsigned(PHASE_INIT);
					phase_acc 			 <= unsigned(PHASE_INIT);
					phase_acc_msbs 		 <= PHASE_MSBS_INIT;
					freq_adjust_q 		 <= (OTHERS => '0');
					rollover_pi2 		 <= '0';
					rollover_pi 		 <= '0';
					rollover_3pi2 	 	 <= '0';
					rollover_2pi		 <= '1';
				ELSE

					IF enable = '1' THEN

						IF freq_adj_valid = '1' THEN
							freq_adjust_q <= freq_adjust;
						END IF;

						IF freq_adj_zero = '1' THEN
							freq_adjust_q <= (OTHERS => '0');
						END IF;

						phase_delta_adjusted <= unsigned(signed(freq_word) + signed(freq_adjust_q));

						phase_acc  			 <= phase_sum;
						phase_acc_msbs 		 <= std_logic_vector(phase_sum(NCO_W -1 DOWNTO NCO_W -2));
						v_phase_acc_msbs 	 := std_logic_vector(phase_sum(NCO_W -1 DOWNTO NCO_W -2));

						rollover_pi2 		 <= '0';
						rollover_pi 		 <= '0';
						rollover_3pi2 	 	 <= '0';
						rollover_2pi		 <= '0';

						tclk_even			 <= '0';
						tclk_odd 			 <= '0';

						IF to_integer(discard_count) = 0 THEN
							discard_count <= unsigned(discard_nco);
							phase 		  <= std_logic_vector(phase_acc);

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

						ELSE
							discard_count <= discard_count -1;
						END IF;

					END IF;

				END IF;
			END IF;
		END PROCESS phase_proc;

	END GENERATE NO_DSP_GEN;

END ARCHITECTURE rtl;

