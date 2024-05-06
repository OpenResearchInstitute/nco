

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY sin_cos_lut IS 
	GENERIC (
		PHASE_W 		: NATURAL 	:= 10;
		PHASES 			: NATURAL 	:= 1024; -- 2**PHASE_W
		SINUSOID_W 		: NATURAL 	:= 10
	);
	PORT (
		clk 			: IN  std_logic;
		init 			: IN  std_logic;

		phase 			: IN  std_logic_vector(PHASE_W -1 DOWNTO 0);

		sin_out			: OUT std_logic_vector(SINUSOID_W -1 DOWNTO 0);
		cos_out			: OUT std_logic_vector(SINUSOID_W -1 DOWNTO 0)
	);
END ENTITY sin_cos_lut;

ARCHITECTURE lut_based OF sin_cos_lut IS 

	TYPE sincos_lut_type IS ARRAY(0 TO PHASES -1) OF signed(SINUSOID_W -1 DOWNTO 0);

	CONSTANT UNIT_PERIOD : REAL := 2.0 * MATH_PI / 1024.0;

	FUNCTION fill_sincos_lut(phases : NATURAL; sin_cos : STRING; width : NATURAL) RETURN sincos_lut_type IS
		VARIABLE tmp 	: REAL;
		VARIABLE v_lut 	: sincos_lut_type;
		VARIABLE theta	: REAL;
	BEGIN

		FOR i IN 0 TO PHASES -1 LOOP

			theta := real(i) * UNIT_PERIOD;

			IF sin_cos = "SIN" THEN
				tmp := ROUND(SIN(theta) * 1024.0);
			ELSE
				tmp := ROUND(COS(theta) * 1024.0);
			END IF;

			v_lut(i) := to_signed(INTEGER(tmp), SINUSOID_W);

		END LOOP;
		RETURN v_lut;
	END FUNCTION fill_sincos_lut;

	SIGNAL cos_lut 			: sincos_lut_type := fill_sincos_lut(PHASES, "COS", SINUSOID_W);
	SIGNAL sin_lut			: sincos_lut_type := fill_sincos_lut(PHASES, "SIN", SINUSOID_W);

	SIGNAL sin_phase 		: signed(SINUSOID_W -1 DOWNTO 0);
	SIGNAL cos_phase 		: signed(SINUSOID_W -1 DOWNTO 0);

BEGIN

	sin_phase 	<= sin_lut(to_integer(unsigned(phase)));
	cos_phase 	<= cos_lut(to_integer(unsigned(phase)));

	sin_out 	<= std_logic_vector(sin_phase);
	cos_out 	<= std_logic_vector(cos_phase);

END ARCHITECTURE lut_based;