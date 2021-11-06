Library ieee;
Use ieee.std_logic_1164.All;
Use ieee.numeric_std.All;
Use ieee.math_real.All;
Library work;
Use work.spectral_pkg.All;

Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

-- effect1d simply transforms a control on range [0, 1) to a bezier curve

Entity effect1d Is
	Generic (
		NOTECOUNT : Integer := 128;
		PROCESS_BW : Integer := 18;
		BEZIER_BW : Integer := 10
	);
	Port (
		clk : In Std_logic;
		rst : In Std_logic;
		Z00_addr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);
		Z06_addr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);

		env_speed_wr : In Std_logic;
		env_bezier_MIDnENDpoint_wr : In Std_logic;

		env_finished_ready : In Std_logic;
		env_finished_valid : Out Std_logic;
		env_finished_addr : Out Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);

		Z06_env : Out sfixed;

		mm_wraddr : In Std_logic_vector(Integer(round(log2(real(NOTECOUNT)))) - 1 Downto 0);
		mm_wrdata : In Std_logic_vector;

		run : Std_logic_vector
	);
End effect1d;

Architecture arch_imp Of effect1d Is
	Constant ADDR_WIDTH : Integer := Integer(round(log2(real(NOTECOUNT))));
	Signal Z03_Env : sfixed(1 Downto -PROCESS_BW + 2) := (Others => '0');

	Signal Z03_run : Std_logic_vector(4 Downto 0);
	Signal Z01_addr : Std_logic_vector(ADDR_WIDTH - 1 Downto 0);
	Signal Z02_addr : Std_logic_vector(ADDR_WIDTH - 1 Downto 0);
	Signal Z03_addr : Std_logic_vector(ADDR_WIDTH - 1 Downto 0);
	Signal Z06_target_BEGnMIDnEND : Std_logic_vector(BEZIER_BW * 3 - 1 Downto 0);

	Signal Z03_addressMatch_i : Std_logic := '0';
	Signal Z04_BEGnMIDnENDpoint_valid : Std_logic := '0';
	Signal Z05_BEGnMIDnENDpoint_valid : Std_logic := '0';
	Signal Z06_BEGnMIDnENDpoint_valid : Std_logic := '0';

	Signal mm_wrdata_processbw   : Std_logic_vector(PROCESS_BW - 1 Downto 0) := (Others => '0');
	Signal mm_wrdata_bezierbw    : Std_logic_vector(BEZIER_BW * 2 - 1 Downto 0) := (Others => '0');
	Signal mm_wrADDRnMIDnEND : Std_logic_vector(ADDR_WIDTH + BEZIER_BW * 2 - 1 Downto 0);

	Signal Z03_ADDRnMIDnEND_valid : Std_logic := '0';
	Signal Z03_ADDRnMIDnEND_ready : Std_logic := '0';
	Signal Z03_ADDRnMIDnEND : Std_logic_vector(ADDR_WIDTH + BEZIER_BW * 2 - 1 Downto 0);
	Signal Z03_ADDRnMIDnEND_addr  : Std_logic_vector (ADDR_WIDTH - 1 Downto 0) := (Others => '0');

	Signal Z04_env_target_endpoint   : sfixed(1 Downto -BEZIER_BW+2);
	Signal Z05_env_target_endpoint   : sfixed(1 Downto -BEZIER_BW+2);
	Signal Z06_env_target_endpoint   : sfixed(1 Downto -BEZIER_BW+2);
	Signal Z04_env_target_midpoint   : sfixed(1 Downto -BEZIER_BW+2);
	Signal Z05_env_target_midpoint   : sfixed(1 Downto -BEZIER_BW+2);
	Signal Z06_env_target_midpoint   : sfixed(1 Downto -BEZIER_BW+2);

	Signal Z06_effect_out : sfixed(Z06_env'high Downto Z06_env'low);

Begin
	Z06_env <= Z06_effect_out;

	mm_wrADDRnMIDnEND <= mm_wraddr & mm_wrdata(BEZIER_BW * 2 - 1 Downto 0);
	Z03_ADDRnMIDnEND_addr <= Z03_ADDRnMIDnEND(ADDR_WIDTH + BEZIER_BW * 2 - 1 Downto BEZIER_BW * 2);
	Z03_addressMatch_i <= '1' When Z03_ADDRnMIDnEND_valid = '1' And Z03_ADDRnMIDnEND_addr = Z03_addr Else '0';
	mm_wrdata_processbw <= mm_wrdata(PROCESS_BW - 1 Downto 0);
	mm_wrdata_bezierbw <= mm_wrdata(BEZIER_BW * 2 - 1 Downto 0);
    Z06_target_BEGnMIDnEND <= 
       std_logic_vector(Z06_effect_out         (1 downto -BEZIER_BW+2)) &
       std_logic_vector(Z06_env_target_midpoint(1 downto -BEZIER_BW+2)) & 
       std_logic_vector(Z06_env_target_endpoint(1 downto -BEZIER_BW+2));

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
			mm_wrdata => mm_wrdata_processbw,
			mm_wraddr => mm_wraddr,

			-- output fifo to indicate when phase is at end
			env_finished_ready => env_finished_ready,
			env_finished_valid => env_finished_valid,
			env_finished_addr  => env_finished_addr,

			-- input fifo to reset phase
			Z03_reset_phase_valid => Z03_addressMatch_i,

			Z00_ADDR => Z00_ADDR,
			Z03_ENV_OUT => Z03_Env

		);

	Z03_run <= run(Z07 Downto Z03);
	-- current env value is written as start point
	env_bez : Entity work.bezier_mm
		Generic Map(
			NOTECOUNT => NOTECOUNT
		)
		Port Map(
			clk => clk,
			rst => rst,

			Z00_ctrl_in => Z03_Env,
			Z00_addr    => Z03_addr,
			env_bezier_BEGnMIDnENDpoint_wr     => Z06_BEGnMIDnENDpoint_valid,
			env_bezier_BEGnMIDnENDpoint_wraddr => Z06_addr,
			env_bezier_BEGnMIDnENDpoint_wrdata => Z06_target_BEGnMIDnEND,

			Z05_Bez_Out => Z06_effect_out,
			run => Z03_run
		);
	addr_process :
	Process (clk)
	Begin
		If rising_edge(clk) Then
		    if Z03_ADDRnMIDnEND_valid = '1' then
			     Z03_ADDRnMIDnEND_ready <= '0';
			end if;
			
			If rst = '0' Then

				If run(Z00) = '1' Then
					Z01_addr <= Z00_addr;
				End If;
				If run(Z01) = '1' Then
					Z02_addr <= Z01_addr;
				End If;
				If run(Z02) = '1' Then
					Z03_addr <= Z02_addr;
				End If;
				If run(Z03) = '1' Then
					-- if address matches, read the next one
					If Z03_addressMatch_i = '1' And Z03_ADDRnMIDnEND_addr = Z03_addr Then
						Z03_ADDRnMIDnEND_ready <= '1';
					End If;

					Z04_BEGnMIDnENDpoint_valid <= Z03_addressMatch_i;
                    Z04_env_target_midpoint  <= sfixed(Z03_ADDRnMIDnEND(2*BEZIER_BW- 1 downto 1*BEZIER_BW));
                    Z04_env_target_endpoint  <= sfixed(Z03_ADDRnMIDnEND(1*BEZIER_BW- 1 downto 0*BEZIER_BW));
                    
				End If;
				If run(Z04) = '1' Then
					Z05_BEGnMIDnENDpoint_valid <= Z04_BEGnMIDnENDpoint_valid;
                    Z05_env_target_endpoint  <= Z04_env_target_endpoint;
                    Z05_env_target_midpoint  <= Z04_env_target_midpoint;
                    
				End If;
				If run(Z07) = '1' Then
					Z06_BEGnMIDnENDpoint_valid <= Z05_BEGnMIDnENDpoint_valid;
                    Z06_env_target_endpoint  <= Z05_env_target_endpoint;
                    Z06_env_target_midpoint  <= Z05_env_target_midpoint;
				End If;
			End If;
		End If;
	End Process;

	-- enqueue all envelope change reqs because we need to process them in time
	fs1 : Entity work.fifo_stream
		Port Map(
			clk => clk,
			rst => rst,
			din_ready  => Open,
			din_valid  => env_bezier_MIDnENDpoint_wr,
			din_data   => mm_wrADDRnMIDnEND,
			dout_ready => Z03_ADDRnMIDnEND_ready,
			dout_valid => Z03_ADDRnMIDnEND_valid,
			dout_data  => Z03_ADDRnMIDnEND
		);

End arch_imp;