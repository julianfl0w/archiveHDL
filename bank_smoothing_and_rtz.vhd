library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
library work;
use work.spectral_pkg.all;
Library ieee_proposed;
use ieee_proposed.fixed_pkg.all;
use ieee_proposed.fixed_float_types.all;

entity bank_smoothing_and_rtz is
generic (
    PROCESS_BW          : integer := 25;
    PHASEPRECISION      : integer := 32;
    VOLUMEPRECISION     : integer := 16;
    BANKCOUNT           : integer := 12;
    SINESPERBANK        : integer := 1024;
    SINESPERBANK_ADDRBW : integer := 10;
    CYCLE_BW            : integer := 8;
    CHANNEL_COUNT       : integer := 2
);
port (
    clk: in std_logic;
    rst: in std_logic;
    
    Z00_volume_wren   : in std_logic_vector(BANKCOUNT -1 downto 0);
    Z00_volume_wrdata : in std_logic_vector(VOLUMEPRECISION-1 DOWNTO 0);
    Z00_volume_wraddr : in std_logic_vector(SINESPERBANK_ADDRBW-1 DOWNTO 0);
    Z00_volume_currcycle : in std_logic_vector(SINESPERBANK_ADDRBW-1 DOWNTO 0);

    S14_PCM_TVALID   : out STD_LOGIC;
    S14_PCM_TREADY   : in  STD_LOGIC;
    S14_PCM_TDATA    : out STD_LOGIC_VECTOR(VOLUMEPRECISION*CHANNEL_COUNT-1 downto 0) := (others=>'0')
    );
end bank_smoothing_and_rtz;

architecture arch_imp of bank_smoothing_and_rtz is

signal S14_PCM_TVALID_int   : STD_LOGIC := '0';
    
signal selectionBit: std_logic := '0';
signal run_7downto2: std_logic_vector(7 downto 2);

signal S13_sum      : sfixed(12 downto -PHASEPRECISION+2)         := (others=>'0');

type S01_RVTYPE is array (0 to BANKCOUNT-1) of std_logic_vector(PHASEPRECISION-1 DOWNTO 0) ;
signal S01_RandVal: S01_RVTYPE := (others=>(others=>'0'));
type S01_RVTYPE_U is array (0 to BANKCOUNT-1) of ufixed(0 downto -PHASEPRECISION+1) ;
signal S01_RandVal_U: S01_RVTYPE_U := (others=>(others=>'0'));

signal Z00_volume_wea       : std_logic;
signal seed_rst       : std_logic;
signal S06_volume_rdaddr    : std_logic_vector(SINESPERBANK_ADDRBW-1 DOWNTO 0)   := (others=>'0');
type S06_AMPTYPE is array (0 to BANKCOUNT-1) of std_logic_vector(VOLUMEPRECISION-1 DOWNTO 0) ;
signal S07_amplitude   : S06_AMPTYPE := (others=>(others=>'0'));
constant dec_amount : unsigned(VOLUMEPRECISION-1 DOWNTO 0) := to_unsigned(2**10, VOLUMEPRECISION);
type VOLUME_AMPTYPE is array (0 to BANKCOUNT-1) of sfixed( 1 downto -VOLUMEPRECISION+2) ;
signal S08_amplitude   : VOLUME_AMPTYPE := (others=>(others=>'0'));
type PHASE_AMPTYPE is array (0 to BANKCOUNT-1) of sfixed( 1 downto -PHASEPRECISION+2) ;
signal S09_sine_adjusted : PHASE_AMPTYPE:= (others=>(others=>'0'));
type PHASE_AMPTYPE_U is array (0 to BANKCOUNT-1) of ufixed(0 downto -PHASEPRECISION+1) ;
type PHASE_AMPTYPE_S is array (0 to BANKCOUNT-1) of sfixed(0 downto -PHASEPRECISION+1) ;
type PHASE_AMPTYPE_SIGNED is array (0 to BANKCOUNT-1) of signed(PHASEPRECISION-1 downto 0) ;
type PROCESS_S is array (0 to BANKCOUNT-1) of sfixed(1 downto -PROCESS_BW+2) ;
signal S08_SINE_out : PROCESS_S       := (others=>(others=>'0'));
signal S01_phase    : PHASE_AMPTYPE_U := (others=>(others=>'0'));
signal S02_phase    : PHASE_AMPTYPE_SIGNED := (others=>(others=>'0'));
signal S01_EX_phase : PHASE_AMPTYPE_U := (others=>(others=>'0'));

type saddrtype is array(S00 to S13) of std_logic_vector(SINESPERBANK_ADDRBW-1 downto 0);
signal saddr : saddrtype:= (others=>(others=>'0'));
signal srun: std_logic_vector(saddr'high downto 0);

type yaddrtype is array(S00 to S15) of std_logic_vector(SINESPERBANK_ADDRBW-1 downto 0);
signal yaddr : yaddrtype:= (others=>(others=>'0'));
signal yrun: std_logic_vector(saddr'high downto 0);

signal S10_BANK_0_1 : sfixed(2 downto -PROCESS_BW+2);
signal S10_BANK_2_3 : sfixed(2 downto -PROCESS_BW+2);
signal S10_BANK_4_5 : sfixed(2 downto -PROCESS_BW+2);
signal S10_BANK_6_7 : sfixed(2 downto -PROCESS_BW+2);
signal S10_BANK_8_9 : sfixed(2 downto -PROCESS_BW+2);

signal S11_BANK_0_1_2_3 : sfixed(3 downto -PROCESS_BW+2);
signal S11_BANK_4_5_6_7 : sfixed(3 downto -PROCESS_BW+2);
signal S11_BANK_8_9     : sfixed(3 downto -PROCESS_BW+2);

signal S12_TOTAL       : sfixed(4 downto -PROCESS_BW+2);

signal Z01_volume_wren   : std_logic_vector(BANKCOUNT -1 downto 0) := (others=>'0');
signal Z01_volume_wrdata : S06_AMPTYPE := (others=>(others=>'0'));
signal Z01_volume_wraddr : std_logic_vector(SINESPERBANK_ADDRBW-1 DOWNTO 0) := (others=>'0');
    
type S07_lastupdateTYPE is array (0 to BANKCOUNT-1) of std_logic_vector(CYCLE_BW-1 DOWNTO 0) ;
signal S07_lastupdate  : S07_lastupdateTYPE := (others=>(others=>'0'));

constant E_INC: PHASE_AMPTYPE_U := 
(
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 0.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 1.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 2.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 3.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 4.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 5.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 6.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 7.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 8.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)* 9.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)*10.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1),  
to_ufixed((E0_FREQ_HZ* (2**(real(SINESPERBANK)*11.0/1200.0) ))/FS_HZ_REAL, 0, -PHASEPRECISION+1)
);


function byteswap32(data : in std_logic_vector(31 downto 0)) return std_logic_vector is begin
    return  data(7  downto  0) &
            data(15 downto  8) &
            data(23 downto 16) &
            data(31 downto 24);
end;

begin

 

run_7downto2<= srun(S06 downto S01);

-- solve each bank independantly
banks:
for bank in 0 to BANKCOUNT-1 generate
   

    lastupdatedArray : entity work.simple_dual_one_clock
    generic map(
        DATA_WIDTH  => CYCLE_BW, 
        ADDR_WIDTH  => SINESPERBANK_ADDRBW
        )
    port map(
        clk    => clk  ,
        wea    => '1'          ,
        wren   => Z00_volume_wren(bank) ,
        wraddr => Z00_volume_wraddr   ,
        wrdata => Z00_volume_currcycle,
        rden   => srun (S06)    ,
        rdaddr => saddr(S06),
        rddata => S07_lastupdate(bank)
    );
    
    lsfr_i: entity work.LFSR
      generic map(
        g_Num_Bits => PHASEPRECISION
        )
      port map(
        Clk       => Clk       ,
        Enable    => srun(S00)  ,
        
        Seed_DV   => seed_rst,
        Seed_Data => std_logic_vector(E_INC(bank)) ,
        
        LFSR_Data => S01_RandVal(bank),
        LFSR_Done => open 
    );

    -- we need to periodically reduce these values 
    -- so they dont get stuck
    -- look how we separate the 2 signal chains 
    volumeBram : entity work.simple_dual_one_clock
    generic map(
        DATA_WIDTH   => VOLUMEPRECISION, 
        ADDR_WIDTH   => SINESPERBANK_ADDRBW
        )
    port map(
        clk    => clk   ,
        rden   => srun(S06),
        wea    => '1'          ,
        wraddr => Z00_volume_wraddr ,
        wrdata => Z00_volume_wrdata,
        wren   => Z00_volume_wren(bank),
        rdaddr => S06_volume_rdaddr ,
        rddata => S07_amplitude(bank)
    );
               
    i_sine_lookup: entity work.sine_lookup 
    Generic MAP(
        OUT_BW  => 25,
        PHASE_WIDTH => 32
    )
    PORT MAP (
        clk100       => clk,
        Z00_PHASE_in => S02_phase(bank),
        Z06_SINE_out => S08_SINE_out(bank),
        run          => run_7downto2
        ); 
    
    -- sine process
    -- all output from ram
    sineproc:
    process (clk)
    begin
      if rising_edge(clk) then 
        
        if rst = '0' then
        
            seed_rst <= '0';
            if srun(S00) = '1' then
                saddr(S00) <= std_logic_vector(unsigned(saddr(S00)) + 1);
                if unsigned(not saddr(S00)) = 0 then
                    S01_phase(bank)    <= S01_EX_phase(bank);
                    S01_EX_phase(bank) <= resize(S01_EX_phase(bank) + E_INC(bank), S01_EX_phase(0), fixed_wrap, fixed_truncate) ;
                    seed_rst <= '1';
                else
                    S01_phase(bank) <= resize(S01_phase(bank) * to_ufixed(sqrt_1200, S01_phase(0)), S01_phase(0), fixed_wrap, fixed_truncate) ;
                end if;
                S01_RandVal_U(bank) <= ufixed(S01_RandVal(bank));
            end if;
            if srun(S01) = '1' then
                S02_phase(bank) <= resize(signed(S01_phase(bank) + S01_RandVal_U(bank)), S02_phase(0)'length);
            end if;
            
            Z01_volume_wren(bank)   <= Z00_volume_wren(bank)   ;
            Z01_volume_wrdata <= Z00_volume_wrdata ;
            Z01_volume_wraddr <= Z00_volume_wraddr ;
            -- if no write from interface, decrease the motha
            if srun(S07) = '1' then
                -- if this ram is not currently being written and data is old
                if Z00_volume_wren(bank) /= '1' and unsigned(Z00_volume_currcycle) - unsigned(S07_lastupdate(bank)) > 5 then
                    Z01_volume_wren(bank) <= '1';
                    Z01_volume_wraddr     <= saddr(S07);
                    -- decrease toward zero
                    if unsigned(S07_amplitude(bank)) < dec_amount then
                        Z01_volume_wrdata <= (others=>'0');
                    else
                        Z01_volume_wrdata <= std_logic_vector(unsigned(S07_amplitude(bank)) - dec_amount);
                    end if;
                end if;
            end if;
            
            if srun(S07) = '1' then
                S08_amplitude(bank) <= sfixed(S07_amplitude(bank));
            end if;
            if srun(S08) = '1' then
                S09_sine_adjusted(bank) <= resize(S08_SINE_out(bank)*S08_amplitude(bank), S09_sine_adjusted(bank), fixed_wrap, fixed_round );
            end if;
            
            
        end if;
      end if;
    end process;
    
    
end generate;
    
zflow_i: entity work.flow
Port map( 
    clk        => clk ,
    rst        => rst ,
    
    in_ready   => open ,
    in_valid   => '1'  ,
    out_ready  => S14_PCM_TREADY,
    out_valid  => S14_PCM_TVALID,
    
    run        => srun      
);

-- sum process\\
sumproc2:
process (clk)
begin
  if rising_edge(clk) then 
    
    if rst = '0' then
        if S14_PCM_TREADY = '1' then
            S14_PCM_TVALID <= '0';
        end if;
        
        addrloop:
        for i in S01 to saddr'high loop
            if srun(i-1) = '1' then
                saddr(i) <= saddr(i - 1);
            end if;
        end loop;
        
        if srun(S09) = '1' then
            S10_BANK_0_1 <= resize(S09_sine_adjusted(0) + S09_sine_adjusted(1), S10_BANK_0_1, fixed_wrap, fixed_truncate);
            S10_BANK_2_3 <= resize(S09_sine_adjusted(2) + S09_sine_adjusted(3), S10_BANK_0_1, fixed_wrap, fixed_truncate);
            S10_BANK_4_5 <= resize(S09_sine_adjusted(4) + S09_sine_adjusted(5), S10_BANK_0_1, fixed_wrap, fixed_truncate);
            S10_BANK_6_7 <= resize(S09_sine_adjusted(6) + S09_sine_adjusted(7), S10_BANK_0_1, fixed_wrap, fixed_truncate);
            S10_BANK_8_9 <= resize(S09_sine_adjusted(8) + S09_sine_adjusted(9), S10_BANK_0_1, fixed_wrap, fixed_truncate);
        end if;
        
        if srun(S10) = '1' then
            S11_BANK_0_1_2_3 <= resize(S10_BANK_0_1 + S10_BANK_2_3, S11_BANK_0_1_2_3, fixed_wrap, fixed_truncate);
            S11_BANK_4_5_6_7 <= resize(S10_BANK_4_5 + S10_BANK_6_7, S11_BANK_0_1_2_3, fixed_wrap, fixed_truncate);
            S11_BANK_8_9     <= resize(S10_BANK_8_9, S11_BANK_0_1_2_3, fixed_wrap, fixed_truncate);
        end if;
        
        if srun(S11) = '1' then
            S12_TOTAL <= resize(S11_BANK_0_1_2_3 + S11_BANK_4_5_6_7 + S11_BANK_8_9, S12_TOTAL, fixed_wrap, fixed_truncate);
        end if;
        
        if srun(S12) = '1' then
            S13_sum <= resize(S13_sum+S12_TOTAL, S13_sum, fixed_wrap, fixed_round );
            if unsigned(saddr(S12)) = SINESPERBANK*BANKCOUNT-1 then
                S13_sum <= resize(S12_TOTAL, S13_sum, fixed_wrap, fixed_round );
                -- for now, mono output
                S14_PCM_TDATA   <= std_logic_vector(S13_sum(12 downto -3)) & std_logic_vector(S13_sum(12 downto -3)) ;
                S14_PCM_TVALID  <= '1';
            end if;
        end if;
    end if;
  end if;
end process;

end arch_imp;