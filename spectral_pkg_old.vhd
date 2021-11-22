library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_misc.ALL;
use ieee.math_real.all;
Library IEEE_PROPOSED;
Use IEEE_PROPOSED.FIXED_PKG.All;

package spectral_pkg is    

    function log2( i : natural) return integer;
    constant cmd_ENVELOPE_MIDnEND   : integer := 1 ;
    constant cmd_ENVELOPE_ENV_SPEED : integer := 3 ;
    constant cmd_PBEND_MIDnEND      : integer := 16;
    constant cmd_PBEND_ENV_SPEED    : integer := 18;
    constant cmd_HWIDTH_3TARGETS    : integer := 32;
    constant cmd_HWIDTH_ENV_SPEED   : integer := 34;
    constant cmd_NFILTER_3TARGETS   : integer := 48;
    constant cmd_NFILTER_ENV_SPEED  : integer := 50;
    constant cmd_GFILTER_3TARGETS   : integer := 64;
    constant cmd_GFILTER_ENV_SPEED  : integer := 67;
    constant cmd_HARMONIC_WIDTH     : integer := 80;
    constant cmd_HARMONIC_WIDTH_INV : integer := 81;
    constant cmd_HARMONIC_BASENOTE  : integer := 82;
    constant cmd_HARMONIC_ENABLE    : integer := 83;
    
    constant cmd_readirqueue        : integer := 64;
    constant cmd_readaudio          : integer := 65;
    constant cmd_readid             : integer := 66;
    
    -- voice params
    constant cmd_static             : integer := 67;
    constant cmd_sounding           : integer := 69;
    constant cmd_fm_algo            : integer := 70;
    constant cmd_am_algo            : integer := 71;
    constant cmd_fbgain             : integer := 73;
    constant cmd_fbsrc              : integer := 74;
    constant cmd_channelgain        : integer := 75;
    
    -- operator params
    constant cmd_env                : integer := 76;
    constant cmd_env_porta          : integer := 77;
    constant cmd_envexp             : integer := 78;
    constant cmd_increment          : integer := 79;
    constant cmd_increment_porta    : integer := 80;
    constant cmd_incexp             : integer := 81;
    
    -- global params
    constant cmd_flushspi           : integer := 120;
    constant cmd_passthrough        : integer := 121;
    constant cmd_shift              : integer := 122;
    constant cmd_env_clkdiv         : integer := 123;
    constant cmd_softreset          : integer := 127;
         
    constant PROCESS_BW : integer := 18;
    constant OPCOUNT : integer := 8;
    constant OPCOUNTLOG2 : integer := 3;
    constant PROCESS_BWA : integer := 18;
    constant PHASE_PRECISIONA : integer := 32;
    Type OPERATOR_PROCESS Is Array (0 To OPCOUNT - 1) Of sfixed(1 Downto -PROCESS_BWA + 2);
    Type OPERATOR_ARRAY Is Array    (0 To OPCOUNT - 1) Of Std_logic_vector(PHASE_PRECISIONA - 1 Downto 0);
    Type OPERATOR_ARRAY_18 Is Array (0 To OPCOUNT - 1) Of Std_logic_vector(PROCESS_BWA - 1 Downto 0);
    Type OPERATOR_ARRAY_SEL Is Array(0 To OPCOUNT - 1) Of unsigned(OPCOUNTLOG2 - 1 Downto 0);
    
    type bezier2dWriteType is array ( 2 downto 0 ) of std_logic_vector(2 downto 0);

    constant MEASUREMAXLOG2 : integer := 7;
    constant BEATMAXLOG2 : integer := 11;
    
    -- define some constants
    constant std_flowwidth   : INTEGER := 25;    -- typical internal signals are 25-bit
    constant ram_width18     : INTEGER := 18;    -- modulator signals are 18 bit
    constant gpif_width      : INTEGER := 16;
    
    constant NOTECOUNT       : INTEGER := 128;
    
    constant time_divisions  : INTEGER := 4;
    constant time_divisionslog2  : INTEGER := log2(time_divisions);
    constant RAMADDR_WIDTH   : INTEGER := 10;
    constant i2s_width       : INTEGER := 16;
    constant i2s_widthlog2   : INTEGER := 4;
    constant mod_clk_div     : integer := 4;
    constant FM_SIGNIFICANCE : INTEGER := 16;
    constant DETUNE_NORM     : INTEGER := 4;
    constant channelscount   : INTEGER := 2;
    constant channelscountlog2: INTEGER:= 1;
    constant oscpervoice     : INTEGER := 4;
    constant oscpervoicelog2 : INTEGER := 2;
    constant oscdepth        : INTEGER := (oscpervoice/time_divisions);
    constant oscdepthlog2    : INTEGER := 1;
    constant LFO_MULTIPLIER  : INTEGER := 6;
    constant ram_width36     : INTEGER := 36;
    constant MULTIPLIERMAX   : INTEGER := 24;
    constant stagecount      : INTEGER := 4;
    constant stagecountlog2  : INTEGER := 2;
    constant envspervoice    : INTEGER := 4;
    constant envspervoicelog2: INTEGER := 2;
    constant DIGAMPMAXLOG2   : INTEGER := 4;
    constant polecount    : INTEGER := 4;
    constant polecountlog2: INTEGER := 2;
    constant panmodcount  : INTEGER := 2;
    constant INSTMODCOUNT : INTEGER := 2;
    constant OScount      : INTEGER := 4;
    constant OScountlog2  : INTEGER := 2;
    constant inputcount   : INTEGER := 4;
    constant inputcountlog2 : INTEGER:= 2;
    
    constant E0_FREQ_HZ : real := 20.60;
    constant sqrt_1200: real := 1.00057778951;

    
    constant FS_HZ : integer := 48000;
    constant FS_HZ_REAL : real := 48000.0;
    constant BYTES_PER_SAMPLE_XFER : natural := 192;
    constant BYTES_PER_SAMPLE   : natural := i2s_width / 8;
    constant HALFSAMPLESPERSEND : natural := BYTES_PER_SAMPLE_XFER/BYTES_PER_SAMPLE;
    constant SAMPLESPERSEND     : natural :=  HALFSAMPLESPERSEND/CHANNELSCOUNT;
        
    -- sdram constants
    constant sdramWidth         : INTEGER := 16;
    constant sdram_rowcount     : natural := 13;
    constant sdram_colcount     : natural := 10;
    constant cycles_per_refresh : natural := 1560;
    constant BANKCOUNT          : natural := 4;
    
    constant GPIF_BUFFERSIZE_IN_WORDS : INTEGER := 8;
    -- two read channels are lowest (Address bits are reversed)
    -- to correspond to FLAGA and FLAGB
    constant GPIFADDR_WRITESAMPLE : STD_LOGIC_VECTOR(1 downto 0) := "11";
    constant GPIFADDR_READSAMPLE  : STD_LOGIC_VECTOR(1 downto 0) := "00";
    constant GPIFADDR_READPARAM   : STD_LOGIC_VECTOR(1 downto 0) := "10";
    constant GPIFADDR_WRITEPULSE  : STD_LOGIC_VECTOR(1 downto 0) := "01";
    
    constant wfcount   : INTEGER := 16;
    constant wfcountlog2: INTEGER := 4;
    
    constant WF_SINE : unsigned(wfcountlog2-1 downto 0) := "0000";
    constant WF_SAW  : unsigned(wfcountlog2-1 downto 0) := "0001";
    constant WF_TRI  : unsigned(wfcountlog2-1 downto 0) := "0010";
    constant WF_SQUARE : unsigned(wfcountlog2-1 downto 0) := "0011";
    
    constant WF_SINE_I : INTEGER := 0;
    constant WF_SAW_I  : INTEGER := 1;
    constant WF_TRI_I  : INTEGER := 2;
    constant WF_SQUARE_I : INTEGER := 3;
    
    constant DRAWSCOUNT  : integer := 64;
    constant DRAWSLOG2   : integer := 6;
    
    constant DRAW_FIXED_I   : INTEGER := 0; 
    constant DRAW_OS_I      : INTEGER := 16; 
    constant DRAW_COMPUTED_ENVELOPE_I : INTEGER := 17;
    constant DRAW_BEAT_I    : INTEGER := 18; 
            
    constant ftypescount: INTEGER := 4;
    constant ftypeslog2 : INTEGER := 2;
    constant FTYPE_NONE : unsigned(1 downto 0) := "00";
    constant FTYPE_LP   : unsigned(1 downto 0) := "01";
    constant FTYPE_HP   : unsigned(1 downto 0) := "10";
    constant FTYPE_BP   : unsigned(1 downto 0) := "11";   
    
    constant FTYPE_NONE_I : INTEGER := 0;
    constant FTYPE_LP_I   : INTEGER := 1;
    constant FTYPE_HP_I   : INTEGER := 2;
    constant FTYPE_BP_I   : INTEGER := 3;
       
    constant DIRECTLY   : unsigned(6 downto 0) := "0000000";
    constant BY_TAG     : unsigned(6 downto 0) := "0000001";
    constant ALL_VOICES : unsigned(6 downto 0) := "0000011";
    constant DUPLICATES : unsigned(6 downto 0) := "0000100";
    
    constant OPTIONS_VALUE : unsigned(3 downto 0) := "0000";
    constant OPTIONS_DRAW  : unsigned(3 downto 0) := "0001";
    
end spectral_pkg;

package body spectral_pkg is
    
    -- add two variables together with positive and negative saturation. 
    -- tested only for two variables of identical size
    function ADDSU (A, B :unsigned) return unsigned is
        variable presum : unsigned(A'length downto 0);
        variable sum : unsigned(A'length - 1 downto 0);
    begin
        if A'length /= B'length then
            report "unequal length args to adds" severity warning;
        end if;
        presum := ('0' & A) + ('0' & B);
    
        if presum(presum'high) = '1' then
            sum := (others=>'1');
        else
            sum := presum(presum'high - 1 downto 0);
        end if;
    
        return sum;
    end function;
    
    -- add two variables together with positive and negative saturation. 
    -- tested only for two variables of identical size
    function ADDS (A, B :signed) return signed is
        variable presum : signed(A'length - 1 downto 0);
        variable sum : signed(A'length - 1 downto 0);
    begin
        if A'length /= B'length then
            report "unequal length args to adds" severity warning;
        end if;
        presum := A + B;
    
        -- if A, B negative, and sum is positive, saturate negative
        if A(A'high) = '1' and B(B'high) = '1' and presum(presum'high) = '0' then
            sum(sum'high) := '1';
            sum(sum'high-1 downto 0) := (others=>'0');
        -- if A. B positive, and sum is negative, saturate positive
        elsif A(A'high) = '0' and B(B'high) = '0' and presum(presum'high) = '1' then 
            sum(sum'high) := '0';
            sum(sum'high-1 downto 0) := (others=>'1');
        -- otherwise sum is presum
        else
            sum := presum;
        end if;
    
        return sum;
    end function;
    
    -- add two variables of different length together with positive and negative saturation. 
    -- longer variable first
    function LJADDS (A, B :signed; L : integer) return signed is
        variable presum : signed(L - 1 downto 0);
        variable sum : signed(L - 1 downto 0);
    begin        
        if A'length < B'length then
            report "provide longer value first to LJADDS" severity warning;
        end if;
        
        if L > A'length then
            report "L must be smaller than A'length" severity warning;
        end if;
        
        if L > B'length then
            presum   := (A(A'high downto A'length - B'length) + B) & A(A'length - B'length - 1 downto A'length - L);
        else
            presum   := A(A'high downto A'length - L) 
            + B(B'high downto A'length - L);
        end if;
    
        -- if A, B negative, and sum is positive, saturate negative
        if A(A'high) = '1' and B(B'high) = '1' and presum(presum'high) = '0' then
            sum(sum'high) := '1';
            sum(sum'high-1 downto 0) := (others=>'0');
        -- if A. B positive, and sum is negative, saturate positive
        elsif A(A'high) = '0' and B(B'high) = '0' and presum(presum'high) = '1' then 
            sum(sum'high) := '0';
            sum(sum'high-1 downto 0) := (others=>'1');
        -- otherwise sum is presum
        else
            sum := presum;
        end if;
    
        return sum(sum'high downto sum'length - L );
    end function;
    
    -- add two variables of different length together, shorten as appropriate from right
    function ADD (A, B :signed; L, D : integer) return signed is
        variable sum : signed(A'high downto 0);
    begin        
        if A'length < B'length then
            report "provide longer value first to ADD" severity warning;
        end if;
        sum := A + B;
    
        return sum(L + D -1 downto D);
    end function;
    
    
    -- multiply two variables, saturating and truncating the result
    -- integer D indicates the decimal point location. 
    -- ex. D=3 results in max signed value 011.1111...
    function MULS (A, B :signed; L, D: integer) return signed is
          variable preprod : signed(A'length + B'length -1 downto 0);
          variable prod   : signed(L -1 downto 0);
          variable allone : std_logic := '1';
          variable allzero: std_logic := '0';
          
    begin
        preprod := A*B;
        
        for i in preprod'high downto preprod'high - D loop
            allone := allone  and preprod(i);
            allzero:= allzero or  preprod(i);
        end loop;
        
        -- product is prepod iff excluded high bits are of a single type
        if allone = '1' or allzero = '0' then
            prod := signed(preprod(preprod'high - D downto preprod'length - L - D));
        -- otherwise, saturate negative if product is negative
        elsif preprod(preprod'high) = '1' then
            prod(prod'high) := '1';
            prod(prod'high-1 downto 0) := (others=>'0');
        -- otherwise, saturate positive
        else
            prod(prod'high)   := '0';
            prod(prod'high -1 downto 0):= (others=>'1');
        end if;
        
        return prod;
    end function;
    
     -- multiply two variables, no saturation
     -- integer D indicates the decimal point location. 
     -- ex. D=2 results in max value 11.11111...
     function MULT (A, B :signed; L, D: integer) return signed is
           variable preprod : signed(A'length + B'length -1 downto 0);
           variable prod : signed(L -1 downto 0);
     begin
        preprod := A*B;
        prod := preprod(preprod'high - D downto preprod'length -L-D);
        return prod;
     end function;
     
     -- return waveform given
     -- input : phase, wftype
     -- output: waveform
     function GETWF(wftype: integer; phase :signed) return signed is
        variable waveform : signed(RAM_WIDTH18-1 downto 0);
     begin
     
     case wftype is
     
--     when WF_SINE_I => -- sine
--         case phase(17 downto 16) is
--         when "00" =>  -- q1: straight lookup
--         waveform := signed('0' & the_sine_lut(to_integer(unsigned(phase(15 downto 9)))));
--         when "01" =>  -- q2: lookup(2**9-index)
--         waveform := signed('0' & the_sine_lut(to_integer(2**8 - 1 - unsigned(phase(15 downto 9)))));
--         when "10" =>  -- q3: -lookup
--         waveform := -signed('0' & the_sine_lut(to_integer(unsigned(phase(15 downto 9)))));
--         when others =>-- q4  -lookup(2**9 -index)
--         waveform := -signed('0' & the_sine_lut(to_integer(2**8 - 1 - unsigned(phase(15 downto 9)))));
--         end case;
             
     when WF_SAW_I  => -- sawtooth is just the MSBs
         waveform := phase; 

     when WF_TRI_I  => -- triangle
         case phase(17 downto 16) is
         when "00" =>  -- q1: -- triangle = phase
         waveform := '0' & phase(15 downto 0) & '0';
         when "01" =>  -- q1: -- triangle = max - phase
         waveform := 2**17-1 - ('0' & phase(15 downto 0) & '0');
         when "10" =>  -- q1: -- triangle = -phase
         waveform := - ('0' & phase(15 downto 0) & '0');
         when others =>  -- q2: phase - max
         waveform := ('0' & phase(15 downto 0) & '0') - 2**17;
        end case;
         
     when others => -- square
         case phase(17) is
         when '0' => -- h1: 2**15 -1
         waveform := to_signed(2**17 - 1, 18);
         when others => -- h2: 2**15 -1
         waveform := to_signed(-2**17 + 1, 18);  
         end case;
     end case;
  return waveform;
  end function;
     
         
   -- log2 function
   function log2( i : natural) return integer is
       variable temp    : integer := i;
       variable ret_val : integer := 0; 
     begin                    
       while temp > 1 loop
         ret_val := ret_val + 1;
         temp    := temp / 2;     
       end loop;
         
       return ret_val;
     end function;
           
end package body;