Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

-- effect2d is intended to be used to create bezier shapes in the spectral domain
-- it can be used for ex. harmonic width, global filter, or note filter
-- the path looks like the following

-- control [0, 1) -> 3 bezier curves -> 2d bezier -> out

Entity effect2d Is
	Generic (
		NOTECOUNT : Integer := 128;
		PROCESS_BW : Integer := 18;
		BEZIER_BW : Integer := 10
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		Z00_addr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);
		Z03_addr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);
		Z06_addr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);

		env_speed_wr : In Std_logic;
		bt_target_endpoints_wr : In Std_logic;

		env_finished_ready : In Std_logic;
		env_finished_valid : Out Std_logic;
		env_finished_addr  : Out Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);

		Z04_Ctrl_2ndStage : In sfixed;
		Z09_effect_out : Out sfixed(1 Downto -PROCESS_BW + 2);

		mm_wraddr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);
		mm_wrdata : In Std_logic_vector;

		run : Std_logic_vector
	);
End effect2d;

Architecture arch_imp Of effect2d Is
	Constant ADDR_WIDTH : Integer := Integer(round(log2(real(NOTECOUNT))));
	Signal Z03_Env : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');

	Type BezierTriple Is Array(0 To 2) Of sfixed(1 Downto -PROCESS_BW + 2);
	Signal Z06_normalized_bezier_point : BezierTriple;
	Type BezierTripleSLV Is Array(0 To 2) Of Std_logic_vector(BEZIER_BW - 1 Downto 0);
	Signal Z06_normalized_bezier_point_slv : BezierTripleSLV := (Others => (Others => '0'));
	Signal Z06_env_target_endpoints : BezierTripleSLV := (Others => (Others => '0'));
	Type combotype Is Array(0 To 2) Of Std_logic_vector(BEZIER_BW * 2 - 1 Downto 0);
	Signal Z06_STARTnEND_POINT : combotype := (Others => (Others => '0'));

	Signal Z05_Ctrl_2ndStage : sfixed(Z04_Ctrl_2ndStage'high downto Z04_Ctrl_2ndStage'low) := (others=>'0');
	Signal Z06_Ctrl_2ndStage : sfixed(Z04_Ctrl_2ndStage'high downto Z04_Ctrl_2ndStage'low) := (others=>'0');
	
	Signal Z01_run : Std_logic_vector(4 Downto 0);

	Signal Z03_3EndPoints_valid_i : Std_logic := '0';
	Signal Z04_3EndPoints_valid : Std_logic := '0';
	Signal Z05_3EndPoints_valid : Std_logic := '0';
	Signal Z06_3EndPoints_valid : Std_logic := '0';
	Signal Z01_addr : Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);

	Signal speed_wrdata : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal mm_wrdata_bezierbw : Std_logic_vector(BEZIER_BW * 3 - 1 Downto 0) := (Others => '0');
	Signal mm_wraddr_and_data : Std_logic_vector(ADDR_WIDTH + BEZIER_BW * 3 - 1 Downto 0);

	Signal Z03_3EndPoints_valid : Std_logic := '0';
	Signal Z03_3EndPoints_ready : Std_logic := '0';
	Signal Z03_env_target_endpoints : Std_logic_vector (BEZIER_BW * 3 - 1 Downto 0) := (Others => '0');
	Signal Z04_env_target_endpoints : Std_logic_vector (BEZIER_BW * 3 - 1 Downto 0) := (Others => '0');
	Signal Z05_env_target_endpoints : Std_logic_vector (BEZIER_BW * 3 - 1 Downto 0) := (Others => '0');
	Signal Z03_3EndPoints_addr : Std_logic_vector (ADDR_WIDTH - 1 Downto 0) := (Others => '0');
	Signal Z03_3EndPoints_addr_and_endpoints : Std_logic_vector (ADDR_WIDTH + BEZIER_BW * 3 - 1 Downto 0) := (Others => '0');

	Signal Z04_run : Std_logic_vector(4 Downto 0);

Begin
	mm_wraddr_and_data <= mm_wraddr & mm_wrdata(BEZIER_BW * 3 - 1 Downto 0);
	Z03_env_target_endpoints <= Z03_3EndPoints_addr_and_endpoints(BEZIER_BW * 3 - 1 Downto 0);
	Z03_3EndPoints_addr <= Z03_3EndPoints_addr_and_endpoints(ADDR_WIDTH + BEZIER_BW * 3 - 1 Downto BEZIER_BW * 3);
	Z03_3EndPoints_valid_i <= '1' When Z03_3EndPoints_valid = '1' And Z03_3EndPoints_addr = Z03_addr Else '0';

	Z06_normalized_bezier_point_slv(0) <= Std_logic_vector(Z06_normalized_bezier_point(0)(1 Downto -BEZIER_BW + 2));
	Z06_normalized_bezier_point_slv(1) <= Std_logic_vector(Z06_normalized_bezier_point(1)(1 Downto -BEZIER_BW + 2));
	Z06_normalized_bezier_point_slv(2) <= Std_logic_vector(Z06_normalized_bezier_point(2)(1 Downto -BEZIER_BW + 2));

	Z06_STARTnEND_POINT(0) <= Z06_normalized_bezier_point_slv(0) & Z06_env_target_endpoints(0);
	Z06_STARTnEND_POINT(1) <= Z06_normalized_bezier_point_slv(1) & Z06_env_target_endpoints(1);
	Z06_STARTnEND_POINT(2) <= Z06_normalized_bezier_point_slv(2) & Z06_env_target_endpoints(2);

	speed_wrdata <= mm_wrdata(PROCESS_BW - 1 Downto 0);
	mm_wrdata_bezierbw <= mm_wrdata(BEZIER_BW * 3 - 1 Downto 0);

	envelope_inst : Entity work.envelope
		Generic Map(
			NOTECOUNT => NOTECOUNT,
			PROCESS_BW => PROCESS_BW
		)
		Port Map(
			clk => clk,
			rst => rst,
			run => run,

			speed_wr => env_speed_wr,
			mm_wrdata => speed_wrdata,
			mm_wraddr => mm_wraddr,

			-- output fifo to indicate when phase is at end
			env_finished_ready => env_finished_ready,
			env_finished_valid => env_finished_valid,
			env_finished_addr => env_finished_addr,

			-- input fifo to reset phase
			Z03_reset_phase_valid => Z03_3EndPoints_valid_i,

			Z00_ADDR => Z00_ADDR,
			Z03_ENV_OUT => Z03_Env

		);

	Z01_run <= run(Z05 Downto Z01);
	firststageloop :
	For i In 0 To 2 Generate

		-- into three linear curves
		env_bez : Entity work.linear_mm
			Generic Map(
				NOTECOUNT => NOTECOUNT
			)
			Port Map(
				clk => clk,
				rst => rst,

				Z02_ctrl_in => Z03_Env,
				Z00_addr => Z01_addr,
				env_3EndPoints_wr     => Z06_3EndPoints_valid,
				env_3EndPoints_wraddr => Z06_addr,
				env_3EndPoints_wrdata => Z06_STARTnEND_POINT(i), -- a combination of target & former value

				Z05_Bez_Out => Z06_normalized_bezier_point(i),
				run => Z01_run
			);

	End Generate;
	-- consolidate the results of the three curves into a new bezier
	Z04_run <= run(Z08 Downto Z04);
	bezierStage1 : Entity work.linear
		Port Map(
			clk => clk,
			rst => rst,

			Z00_X => Z06_Ctrl_2ndStage,

			Z00_STARTPOINT => Z06_normalized_bezier_point(0),
			--Z02_MIDPOINT => Z06_normalized_bezier_point(1),
			Z00_ENDPOINT => Z06_normalized_bezier_point(2),

			-- the output of which is the harmonic width on range [0, 1)
			Z03_Y => Z09_effect_out,

			run => Z04_run
		);

	addr_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
			if Z03_3EndPoints_valid = '1' then 
			 Z03_3EndPoints_ready <= '0';
			end if;
			If rst = '0' Then
				If run(Z00) = '1' Then
					Z01_addr <= Z00_addr;
				End If;
				If run(Z03) = '1' Then
					-- if address matches, read the next one
					If Z03_3EndPoints_valid_i = '1' Then
						Z03_3EndPoints_ready <= '1';
					End If;

					Z04_3EndPoints_valid <= Z03_3EndPoints_valid_i;
					Z04_env_target_endpoints <= Z03_env_target_endpoints;
				End If;
				If run(Z04) = '1' Then
					Z05_3EndPoints_valid <= Z04_3EndPoints_valid;
					Z05_env_target_endpoints <= Z04_env_target_endpoints;
					Z05_Ctrl_2ndStage <= Z04_Ctrl_2ndStage;
				End If;
				If run(Z05) = '1' Then
					Z06_Ctrl_2ndStage <= Z05_Ctrl_2ndStage;
					Z06_3EndPoints_valid <= Z05_3EndPoints_valid;
					Z06_env_target_endpoints(0) <= Z05_env_target_endpoints((0 + 1) * BEZIER_BW - 1 Downto 0 * BEZIER_BW);
					Z06_env_target_endpoints(1) <= Z05_env_target_endpoints((1 + 1) * BEZIER_BW - 1 Downto 1 * BEZIER_BW);
					Z06_env_target_endpoints(2) <= Z05_env_target_endpoints((2 + 1) * BEZIER_BW - 1 Downto 2 * BEZIER_BW);
				End If;
			End If;
		End If;
	End Process;

	-- enqueue all envelope change reqs because we need to process them in time
	fs1 : Entity work.fifo_stream
	   Generic Map(
	       FIFO_SIZE => "36Kb"
	   )
		Port Map(
			clk => clk,
			rst => rst,
			din_ready  => Open,
			din_valid  => bt_target_endpoints_wr,
			din_data   => mm_wraddr_and_data,
			dout_ready => Z03_3EndPoints_ready,
			dout_valid => Z03_3EndPoints_valid,
			dout_data  => Z03_3EndPoints_addr_and_endpoints
		);

End arch_imp;