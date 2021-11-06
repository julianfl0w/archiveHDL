library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.std_logic_misc.ALL;

package memory_word_type is    

    function log2( i : natural) return integer;
    
    
    constant MEASUREMAXLOG2 : integer := 7;
    constant BEATMAXLOG2 : integer := 11;
    
    -- define some constants
    constant std_flowwidth   : INTEGER := 25;    -- typical internal signals are 25-bit
    constant ram_width18     : INTEGER := 18;    -- modulator signals are 18 bit
    constant gpif_width      : INTEGER := 16;
    
    constant instcount       : INTEGER := 4;
    constant instcountlog2   : INTEGER := log2(instcount);
    constant voicecount      : INTEGER := 1024/4; -- 256
    constant voicecountlog2  : INTEGER := log2(voicecount); -- 8
    constant voicesperinst   : INTEGER := voicecount/instcount; -- 64
    constant voicesperinstlog2: INTEGER := 6; -- 6
    
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
    constant POLYLFOSpervoice : INTEGER := 4;
    constant oneshotspervoice : INTEGER := POLYLFOSpervoice;
    constant POLYLFOSpervoicelog2: INTEGER := 2;
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
    
    constant eventtag_width  : INTEGER := stagecountlog2 + instcountlog2 + voicesperinstlog2 + OScountlog2;
        
    constant FS_HZ : integer := 48000;
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
    
    constant ZN12 : integer := -12;
    constant ZN11 : integer := -11;
    constant ZN10 : integer := -10;
    constant ZN9 : integer := -9;
    constant ZN8 : integer := -8;
    constant ZN7 : integer := -7;
    constant ZN6 : integer := -6;
    constant ZN5 : integer := -5;
    constant ZN4 : integer := -4;
    constant ZN3 : integer := -3;
    constant ZN2 : integer := -2;
    constant ZN1 : integer := -1;
    constant Z00 : integer := 0;
    constant Z01 : integer := 1;
    constant Z02 : integer := 2;
    constant Z03 : integer := 3;
    constant Z04 : integer := 4;
    constant Z05 : integer := 5;    
    constant Z06 : integer := 6;
    constant Z07 : integer := 7;
    constant Z08 : integer := 8;
    constant Z09 : integer := 9;
    constant Z10 : integer := 10;
    constant Z11 : integer := 11;
    constant Z12 : integer := 12;
    constant Z13 : integer := 13;
    constant Z14 : integer := 14;
    constant Z15 : integer := 15;    
    constant Z16 : integer := 16;
    constant Z17 : integer := 17;
    constant Z18 : integer := 18;
    constant Z19 : integer := 19;
    constant Z20 : integer := 20;
    constant Z21 : integer := 21;
    constant Z22 : integer := 22;
    constant Z23 : integer := 23;   
    constant Z24 : integer := 24;      
    constant Z25 : integer := 25;    
    constant Z26 : integer := 26;
    constant Z27 : integer := 27;
    constant Z28 : integer := 28;
    constant Z29 : integer := 29;     
    constant Z30 : integer := 30;
    constant Z31 : integer := 31;
    constant Z32 : integer := 32;
    constant Z33 : integer := 33;
    constant Z34 : integer := 34;
    constant Z35 : integer := 35;    
    constant Z36 : integer := 36;
    constant Z37 : integer := 37;
    constant Z38 : integer := 38;
    constant Z39 : integer := 39;
    constant Z40 : integer := 40;
    constant Z41 : integer := 41;
    constant Z42 : integer := 42;
    constant Z43 : integer := 43;
    constant Z44 : integer := 44;
    constant Z45 : integer := 45;    
    constant Z46 : integer := 46;
    constant Z47 : integer := 47;
    constant Z48 : integer := 48;
    constant Z49 : integer := 49;
    constant Z50 : integer := 50;   
    constant Z51 : integer := 51;
    constant Z52 : integer := 52;
    constant Z53 : integer := 53;
    constant Z54 : integer := 54;
    constant Z55 : integer := 55;    
    constant Z56 : integer := 56;
    constant Z57 : integer := 57;
    constant Z58 : integer := 58;
    constant Z59 : integer := 59;
    constant Z60 : integer := 60;   
    constant Z61 : integer := 61;
    constant Z62 : integer := 62;
    constant Z63 : integer := 63;
    constant Z64 : integer := 64;
    constant Z65 : integer := 65;
    constant Z66 : integer := 66;
    constant Z67 : integer := 67;
    constant Z68 : integer := 68;
    constant Z69 : integer := 69;
    
    type doubleSDRAMdata is array (0 to 1) of std_logic_vector (sdramWidth-1 downto 0);
    
    constant maxADDRpropagate : integer := Z66;
    type address_type is array(ZN12 to maxADDRpropagate) of unsigned(RAMADDR_WIDTH-1 downto 0);
    
    constant tapsperinst     : integer := 3; 
    constant tapsperinstlog2 : integer := 2;
    constant totaltapcount     : integer := instcount     * channelscount     * tapsperinst;
    constant totaltapcountlog2 : integer := instcountlog2 + channelscountlog2 + tapsperinstlog2;
    type instcount_times_channelcount_times_delaytaps is array(0 to totaltapcount-1) of unsigned(sdram_rowcount + log2(BANKCOUNT) + sdram_colcount - instcountlog2 - channelscountlog2 - tapsperinstlog2 - 1 downto 0);
    type instcount_by_delaytaps_by_ramwidth   is array(0 to instcount-1, 0 to tapsperinst-1) of signed(RAM_WIDTH18 - 1 downto 0);
    type instcount_by_delaytaps_by_ramwidth18u  is array(0 to instcount-1, 0 to tapsperinst-1) of unsigned(RAM_WIDTH18 - 1 downto 0);
    type instcount_by_delaytaps_by_drawslog2  is array(0 to instcount-1, 0 to tapsperinst-1) of unsigned(drawslog2-1 downto 0);

        
    type instcount_by_instmods_by_ramwidth18 is array(0 to instcount-1, 0 to INSTMODCOUNT-1) of signed(ram_width18-1 downto 0);
    type globaloneshots_by_ramwidth18  is array(0 to OScount-1) of signed(ram_width18-1 downto 0);
    type globaloneshots_by_ramwidth18u is array(0 to OScount-1) of unsigned(ram_width18-1 downto 0);
   
    type instcount_by_ftypeslog2 is array(0 to instcount-1) of integer range 0 to ftypescount-1;
    type instcount_by_drawslog2  is array(0 to instcount-1) of unsigned(drawslog2-1 downto 0);
    type instcount_by_polecount_by_ftypeslog2 is array(0 to instcount-1, 0 to polecount-1) of integer range 0 to ftypescount-1;
    type instcount_by_polecount_by_drawslog2  is array(0 to instcount-1, 0 to polecount-1) of unsigned(drawslog2-1 downto 0);
    type instcount_by_integer is array(0 to instcount-1) of integer;
    type instcount_by_envspervoice_by_drawslog2  is array(0 to instcount-1, 0 to envspervoice -1) of unsigned(drawslog2-1 downto 0);
                           
    type instcount_by_oscpervoice_by_2 is array(0 to instcount-1, 0 to oscpervoice-1) of unsigned(1 downto 0);
    type instcount_by_oscpervoice_by_oscpervoice is array(0 to instcount-1, 0 to oscpervoice-1) of unsigned(oscpervoice-1 downto 0);
    type instcount_by_oscpervoice_by_oscpervoice_by_ramwidth18 is array(0 to instcount-1, 0 to oscpervoice-1, 0 to oscpervoice-1) of signed(ram_width18-1 downto 0);
    type instcount_by_oscpervoice_by_oscpervoice_by_drawslog2  is array(0 to instcount-1, 0 to oscpervoice-1, 0 to oscpervoice-1) of unsigned(drawslog2-1 downto 0);
    type instcount_by_oscpervoice_by_wfcountlog2 is array(0 to instcount-1, 0 to oscpervoice-1) of integer range 0 to wfcount-1;
    type instcount_by_oscpervoice_by_drawslog2   is array(0 to instcount-1, 0 to oscpervoice-1) of unsigned(drawslog2-1 downto 0);
    type instcount_by_oscpervoice_by_ramwidth18  is array(0 to instcount-1, 0 to oscpervoice-1) of signed(ram_width18-1 downto 0);
    type oscpervoice_by_stdflowwidth is array (0 to oscpervoice -1) of signed(std_flowwidth-1 downto 0);
    type oscpervoice_by_ramwidth18 is array (0 to oscpervoice -1) of signed(ram_width18-1 downto 0);
    type instcount_by_ramwidth18   is array(0 to instcount-1) of signed(ram_width18-1 downto 0);
    type instcount_by_2_by_ramwidth18   is array(0 to instcount-1, 0 to 1) of signed(ram_width18-1 downto 0);
    type instcount_by_stdflowwidth is array(0 to instcount-1) of signed(std_flowwidth-1 downto 0);
    type instcount_by_ramwidth18u  is array(0 to instcount-1) of unsigned(ram_width18-1 downto 0);
    
    type insts_by_oneshotspervoice_by_stagecount_by_ramwidth18 is array(0 to instcount-1, 0 to oneshotspervoice-1, 0 to stagecount -1) of signed(ram_width18-1 downto 0);     
    type insts_by_oneshotspervoice_by_stagecount  is array(0 to instcount-1, 0 to oneshotspervoice-1) of integer range 0 to stagecount-1;           
    type insts_by_oneshotspervoice_by_drawslog2   is array(0 to instcount-1, 0 to oneshotspervoice-1) of unsigned(drawslog2-1 downto 0);
    type insts_by_oneshotspervoice_by_wfcountlog2 is array(0 to instcount-1, 0 to oneshotspervoice-1) of integer range 0 to wfcount-1;
    
    type instcount_by_channelcount_by_panmodcount_by_ramwidth18s is array(0 to instcount-1, 0 to channelscount-1, 0 to panmodcount-1) of  signed(ram_width18-1 downto 0);
    type instcount_by_channelcount_by_panmodcount_by_drawslog2   is array(0 to instcount-1, 0 to channelscount-1, 0 to panmodcount-1) of unsigned(drawslog2-1 downto 0);
  
    type instcount_by_COMPUTED_ENVELOPESlog2 is array(0 to instcount-1) of unsigned(1 downto 0);
            
    type channels_by_stdflowwidth is array(0 to channelscount-1) of signed(std_flowwidth -1 downto 0);
    type channels_by_ramwidth     is array(0 to channelscount-1) of signed(ram_width18 -1 downto 0);
      
    type oneshotspervoice_by_ramwidth18  is array(0 to oneshotspervoice-1) of std_logic_vector(ram_width18-1 downto 0);   
    type oneshotspervoice_by_ramwidth18u is array(0 to oneshotspervoice-1) of unsigned(ram_width18-1 downto 0);     
    type oneshotspervoice_by_ramwidth18s is array(0 to oneshotspervoice-1) of signed(ram_width18-1 downto 0);      
        
    type POLYLFOSpervoice_by_ramwidth18  is array(0 to POLYLFOSpervoice-1) of std_logic_vector(ram_width18-1 downto 0);       
    type inputcount_by_ramwidth18s is array(0 to inputcount-1) of signed(ram_width18-1 downto 0);       

    type LFOcount_by_stdflowwidth is array(0 to POLYLFOSpervoice-1) of signed(std_flowwidth-1 downto 0);    
    type LFOcount_by_ramwidth18   is array(0 to POLYLFOSpervoice-1) of signed(ram_width18-1 downto 0);
    type LFOcount_by_lfocountlog2 is array(0 to POLYLFOSpervoice-1) of integer range 0 to POLYLFOSpervoice-1;
    type LFOcount_by_wfcountlog2  is array(0 to POLYLFOSpervoice-1) of integer range 0 to wfcount-1;
 
    constant P_VOICESHIFT  :integer := 0;
    constant P_VOICE_INC   :integer := 2;
    constant P_VOICE_ENV        :integer := 4;
    constant P_VOICE_PAN        :integer := 6;
    
    constant P_VOICE_PORTRATE :integer := 10;
    constant P_VOICE_UNISON   :integer := 12;
    constant P_VOICE_UNISON_DET:integer := 14;
    constant P_VOICE_UNISON_MIDPOINT:integer := 16;
    constant P_VOICE_FILT_Q   :integer := 18;
    constant P_VOICE_FILT_F   :integer := 20;
    constant P_VOICE_FILT_TYP :integer := 22;
    constant P_VOICE_SPAWN    :integer := 24;
    
    constant P_OSC_DETUNE     :integer := 32;
    constant P_OSC_MODAMP     :integer := 34;
    constant P_OSC_VOLUME     :integer := 36;
    constant P_OSC_WAVEFORM   :integer := 38;
    constant P_OSC_HARMONICITY :integer := 40;
    constant P_OSC_HARMONICITY_A  :integer := 42;
    constant P_OSC_RINGMOD     :integer := 44;
    
    constant P_ONESHOT_STAGESET     :integer := 64;
    constant P_ONESHOT_RATE         :integer := 66;
    constant P_ONESHOT_STARTPOINT_Y :integer := 68;
    constant P_ONESHOT_MIDPOINT_Y   :integer := 70;
    constant P_ONESHOT_DIVSPERSTAGE :integer := 72;
   
    constant P_DELAY_SAMPLES      :integer := 78;
    constant P_SAP_FB_GAIN        :integer := 80;
    constant P_SAP_COLOR_GAIN     :integer := 82;
    constant P_SAP_FORWARD_GAIN   :integer := 84;
    constant P_SAP_INPUT_GAIN     :integer := 86;
   
    constant P_INSTVOL   : integer := 88;
    constant P_INST_DET  : integer := 90;
    constant P_INSTSHIFT     : integer := 92;
   
    constant P_TEMPO       :integer := 98;
    constant P_BEATCOUNT   :integer := 100;
    
    constant P_NULL   :integer := 102;
    constant P_INIT   :integer := 104;
        
    -- begin global parameters
    constant P_BEATPULSE   :integer := 126;
    constant P_SOF         :integer := 128;
    
    constant P_LCD_COMMAND :integer := 148;
    constant P_LCD_DATA    :integer := 150;
    constant P_LCD_RESET   :integer := 152;
    constant P_LCD_FILLRECT:integer := 154;
    constant P_LCD_SETCOLOR:integer := 156;
    constant P_LCD_SETCOLUMN:integer := 158;
    constant P_LCD_SETROW   :integer := 160;
    constant P_LCD_DRAWSQUARES:integer:= 162;
    
    
    -- COLOR TYPE CONSTANTS
    constant COLOR_BASE : std_logic_vector := "000";
    constant COLOR_dRx : std_logic_vector := "001";
    constant COLOR_dGx : std_logic_vector := "010";
    constant COLOR_dBx : std_logic_vector := "011";
    constant COLOR_dRy : std_logic_vector := "100";
    constant COLOR_dGy : std_logic_vector := "101";
    constant COLOR_dBy : std_logic_vector := "110";

    
    -- LCD programs
    
    constant LCD_COMMAND  : std_logic_vector(2 downto 0) := "000";
    constant LCD_DATA     : std_logic_vector(2 downto 0) := "001";
    constant LCD_RESET    : std_logic_vector(2 downto 0) := "010";
    constant LCD_FILLRECT : std_logic_vector(2 downto 0) := "011";
    constant LCD_SETCOLOR : std_logic_vector(2 downto 0) := "100";
    constant LCD_SETCOLUMN: std_logic_vector(2 downto 0) := "101";
    constant LCD_SETROW   : std_logic_vector(2 downto 0) := "110";
    constant LCD_DRAWSQUARES:std_logic_vector(2 downto 0):= "111";
    
    function ADD  (A, B :signed; L, D: integer) return signed;
    function ADDS (A, B :signed) return signed;
    function ADDSU(A, B :unsigned) return unsigned;
    function LJADDS (A, B :signed; L: INteger) return signed;
    function MULS (A, B :signed; L, D: integer) return signed;
    function MULT (A, B :signed; L, D: integer) return signed;
    function GETWF(wftype: integer; phase :signed) return signed;
    function CHOOSEMOD3(modtype: unsigned; fixed: signed; oneSHOT: oneshotspervoice_by_ramwidth18s; COMPUTED_ENVELOPE: inputcount_by_ramwidth18s) return signed;    
    function CHOOSEMOD4(modtype: unsigned; fixed: unsigned; beatlocked: unsigned; oneSHOT: oneshotspervoice_by_ramwidth18s; COMPUTED_ENVELOPE: inputcount_by_ramwidth18s) return unsigned;

    constant FBGAIN_ADDR      : std_logic_vector(1 downto 0) := std_logic_vector(to_unsigned(0,2));
    constant FORWARDGAIN_ADDR : std_logic_vector(1 downto 0) := std_logic_vector(to_unsigned(1,2));
    constant COLORGAIN_ADDR   : std_logic_vector(1 downto 0) := std_logic_vector(to_unsigned(2,2));
    constant INPUT_GAIN_ADDR  : std_logic_vector(1 downto 0) := std_logic_vector(to_unsigned(3,2));
    constant FBGAIN_ADDR_i      : integer := 0;
    constant FORWARDGAIN_ADDR_i : integer := 1;
    constant COLORGAIN_ADDR_i   : integer := 2;
    constant INPUT_GAIN_ADDR_i  : integer := 3;
        
    
end memory_word_type;

package body memory_word_type is
    
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
     
         
   -- CHOOSEMOD3 is a simple but common case statement
   -- to choose between different available mods.
   -- when LFO is unavailable
   function CHOOSEMOD3(modtype: unsigned; fixed: signed; oneSHOT: oneshotspervoice_by_ramwidth18s; COMPUTED_ENVELOPE: inputcount_by_ramwidth18s) return signed is
       variable modulator : signed(fixed'high downto 0) := (others=>'0');
   begin
   case to_integer(modtype) is
   when DRAW_COMPUTED_ENVELOPE_I =>
       modulator(fixed'high downto fixed'length - RAM_WIDTH18) := COMPUTED_ENVELOPE(to_integer(unsigned(fixed(inputcountlog2 -1 downto 0))));
   when DRAW_OS_I =>
       modulator(fixed'high downto fixed'length - RAM_WIDTH18) := oneSHOT(to_integer(unsigned(fixed(POLYLFOSpervoicelog2 -1 downto 0))));
   when others=>
       modulator := fixed;
   end case;        
   return modulator;
   end function;
         
      
    -- CHOOSEMOD3 is a simple but common case statement
    -- to choose between different available mods.
    -- when LFO is unavailable
    function CHOOSEMOD4(modtype: unsigned; fixed: unsigned; beatlocked: unsigned; oneSHOT: oneshotspervoice_by_ramwidth18s; COMPUTED_ENVELOPE: inputcount_by_ramwidth18s) return unsigned is 
    variable modulator : unsigned(beatlocked'high downto 0) := (others=>'0');
    begin
    case to_integer(modtype) is
    when DRAW_COMPUTED_ENVELOPE_I =>
      modulator(beatlocked'high downto beatlocked'length - RAM_WIDTH18) := unsigned(COMPUTED_ENVELOPE(to_integer(unsigned(fixed(inputcountlog2 -1 downto 0)))));
    when DRAW_OS_I =>
      modulator(beatlocked'high downto beatlocked'length - RAM_WIDTH18) := unsigned(oneSHOT(to_integer(unsigned(fixed(POLYLFOSpervoicelog2 -1 downto 0)))));
    when DRAW_BEAT_I => 
      modulator := beatlocked;
    when others=>
      modulator(RAM_WIDTH18 + 1 downto 2) := fixed;
    end case;        
    return modulator;
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