----------------------------------------------------------------------------------
-- Company: DRAGONTECH
-- Engineer: JULAN
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


library work;
use work.memory_word_type.all;
use work.fixed_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity gpif_ii_top_tb is
--  Port ( );
end gpif_ii_top_tb;

architecture Behavioral of gpif_ii_top_tb is

component gpif_ii_top is
generic(
    EXCLUDE_SIG_CHAIN : integer := 0
);
Port ( 
    I2S_BCLK   : out std_logic;
    I2S_LRCLK  : out std_logic;
    I2S_DACSD  : out std_logic;
    I2S_ADCSD  : in std_logic;
    clk100     : in STD_LOGIC;
    
    -- GPIF Signals
    GPIF_CLK   : out std_logic;               ---output clk 100 Mhz and 180 phase shift 
    GPIF_SLCS  : out std_logic := '1';        ---output chip select
    GPIF_DATA  : inout std_logic_vector(gpif_width -1 downto 0) := (others=>'Z');         
    GPIF_ADDR  : out std_logic_vector(1 downto 0) := (others=>'0');  ---output fifo address
    GPIF_SLRD  : out std_logic := '1';        ---output read select
    GPIF_SLOE  : out std_logic := '1';        ---output output enable select
    GPIF_SLWR  : out std_logic := '1';        ---output write select
    GPIF_FLAGA : in std_logic := '1';                              
    GPIF_FLAGB : in std_logic := '1';  
    GPIF_PKTEND: out std_logic := '1';        ---output pkt end
        
    -- Tempo signals
    TEMPO_SW   : in std_logic;                                
    TEMPO_LED  : out std_logic := '0';
    
    -- LCD signals
    LCD_RST : out std_logic := '1';
    LCD_CSX : out std_logic := '1';
    LCD_WRX : out std_logic := '1';
    LCD_RDX : out std_logic := '1';
    LCD_DCX : out std_logic := '1';
    LCD_D   : inout std_logic_vector(17 downto 0);
    LCD_IM  : out std_logic_vector(3 downto 0) := "0011"; -- 8080-I 18-bit
    
    LCD_SDA    : out std_logic := '0';
    LCD_SDO    : in  std_logic;
    LCD_TE     : in  std_logic; 
    LCD_DOTCLK : out std_logic := '0';
    LCD_HSYNC  : out std_logic := '0';
    LCD_VSYNC  : out std_logic := '0';
    LCD_DE     : out std_logic := '0';
    
    LED_G : out std_logic := '1';
    LED_R : out std_logic := '0';
    LED_B : out std_logic := '0'
        );
end component;


signal SAMPLEREAD_COUNT : integer := 0;
constant INSTNUM   : unsigned(14 downto 0) := to_unsigned(0, 15);
constant VOICETAG0 : unsigned(14 downto 0) := to_unsigned(30, 15);
constant VOICETAG1 : unsigned(14 downto 0) := to_unsigned(7, 15);
constant OSCNUM  : unsigned(14 downto 0) := to_unsigned(0, 15);
constant OSNUM   : INTEGER := 0;
constant DOSRATE : unsigned(35 downto 0) := to_unsigned(2**17, 36);

constant clk100_period : time := 10 ns;
signal clk100     : STD_LOGIC := '0';
signal I2S_BCLK   : std_logic;
signal I2S_LRCLK  : std_logic;
signal I2S_DACSD  : std_logic;
signal I2S_ADCSD  : std_logic := '0';
    
    -- GPIF Signals
signal GPIF_CLK   : std_logic;        ---output clk 100 Mhz and 180 phase shift 
signal GPIF_SLCS  : std_logic;        ---output chip select
signal GPIF_DATA  : std_logic_vector(gpif_width -1 downto 0) := (others=>'Z');         
signal GPIF_ADDR  : std_logic_vector(1 downto 0);  ---output fifo address
signal GPIF_SLRD  : std_logic;        ---output read select
signal GPIF_SLOE  : std_logic;        ---output output enable select
signal GPIF_SLWR  : std_logic;        ---output write select
signal GPIF_FLAGA : std_logic := '1';                                
signal GPIF_FLAGB : std_logic := '1';
signal GPIF_PKTEND: std_logic;        ---output pkt end
    
    -- Tempo signals
signal TEMPO_SW   : std_logic := '0';                                
signal TEMPO_LED  : std_logic := '0';  
           
signal LCD_SDO    : std_logic;
signal LCD_TE     : std_logic; 
                 
signal SOF  : std_logic := '0';
signal SOFcount  : integer := 0;
signal BP  : std_logic := '0';
signal BPcount  : integer := 0;
signal BPSENT   : integer := 0;
signal RWSTATE   : integer := 0;
signal OSEVENT  : std_logic := '0';
signal OSEVENTcount  : integer := 0;

-- raise FLAGA every SAMPLES_PER_XFER * CLOCKSPERSAMPLE
signal   NEXT_SAMPLEPRODUCE_COUNTER    : integer := 0;
-- fuck it up by 200PPM (happens to be 2)
constant NEXT_SAMPLEPRODUCE_COUNTER_MAX: integer := (SAMPLESPERSEND*30000000/48000) - (200*SAMPLESPERSEND*30000000)/(48000*1000000);
signal samplegen_clk : std_logic :=  '0';
-- 1/30000000 sec
constant samplegen_clk_period : time := 33.3333333 ns;
signal USB_RDY_TO_SEND_PACKET: std_logic := '0';
signal SAMPLEPROD_last: std_logic := '0';
signal outbuffersamplecount : integer := 0;

signal Z01_EXSAMPLE: unsigned(gpif_width-1 downto 0) := (others=>'0');
signal Z02_EXSAMPLE: unsigned(gpif_width-1 downto 0) := (others=>'0');

constant initparamcount: integer := 103;
-- +1 for SOF param
type initparamarray is array (0 to initparamcount-1) of unsigned(14 downto 0);
signal PN : initparamarray := (others=>to_unsigned(P_NULL, 15));
signal INSTNO  : initparamarray := (others=>INSTNUM);
signal VOICENO : initparamarray := (others=>VOICETAG0);
signal A1 : initparamarray := (others=>OSCNUM);
signal A0 : initparamarray := (others=>(others=>'0'));
type initoptionsarray is array (0 to initparamcount-1) of unsigned(6 downto 0);
signal OP : initoptionsarray := (others=>BY_TAG); 
type initpayloadarray is array (0 to initparamcount-1) of unsigned(35 downto 0);
signal PL : initpayloadarray := (others=>(others=>'0'));
signal ZN1_PARAMPTR : integer range 0 to 7 := 0;
signal Z00_PARAMPTR : integer range 0 to 7 := 0;
signal ZN1_PN  : integer := 0;
signal Z00_PN  : integer := 0;
signal INIT_PARAMS : std_logic := '1';

-- late parameters
constant lateparamcount: integer := 3;
type lateparamarray is array (0 to lateparamcount-1) of unsigned(14 downto 0);
constant SOF_ADDR     : integer := 0;
constant BP_ADDR      : integer := 1;
constant OSEVENT_ADDR : integer := 2;

signal L_PN : initparamarray := (others=>to_unsigned(P_NULL, 15));
signal L_INSTNO  : initparamarray := (others=>INSTNUM);
signal L_VOICENO : initparamarray := (others=>VOICETAG0);
signal L_A1 : initparamarray := (others=>OSCNUM);
signal L_A0 : initparamarray := (others=>(others=>'0'));
type lateoptionsarray is array (0 to lateparamcount-1) of unsigned(6 downto 0);
signal L_OP : lateoptionsarray := (others=>BY_TAG);
type latepayloadarray is array (0 to lateparamcount-1) of unsigned(35 downto 0);
signal L_PL : initpayloadarray := (others=>(others=>'0'));
signal L_ZN1_PARAMPTR : integer range 0 to 7 := 0;
signal L_Z00_PARAMPTR : integer range 0 to 7 := 0;


signal ZN1_TESTSAW : signed(gpif_width -1 downto 0) := (others=>'0');
signal Z00_TESTSAW : signed(gpif_width -1 downto 0) := (others=>'0');


signal ZN1_GPIF_FLAGA : std_logic := '0';
signal ZN2_GPIF_FLAGA : std_logic := '0';

constant fifolength : natural := 4*(BYTES_PER_SAMPLE_XFER/BYTES_PER_SAMPLE);
signal readptr: integer := fifolength - BYTES_PER_SAMPLE_XFER/BYTES_PER_SAMPLE;
signal writeptr: integer := 0;
type CHANNELTYPE is array (0 to channelscount - 1) of std_logic_vector(i2s_width -1 downto 0);
signal CHANNEL : CHANNELTYPE := (others=>(others=>'0'));
type OUTCHANNELFIFOTYPE is array (0 to channelscount - 1, 0 to fifolength -1) of std_logic_vector(i2s_width -1 downto 0);
signal CHANNELFIFO : OUTCHANNELFIFOTYPE := (others=>(others=>(others=>'0')));
signal currchan : integer := 0;
signal thisRead : std_logic_vector(i2s_width -1 downto 0);

begin

CHANNEL(0) <= CHANNELFIFO(0,readptr);
CHANNEL(1) <= CHANNELFIFO(1,readptr);

i_gpif_ii_top: gpif_ii_top 
GENERIC MAP(
    EXCLUDE_SIG_CHAIN => 0
)

PORT MAP(
    clk100     => clk100,
    I2S_BCLK   => I2S_BCLK,
    I2S_LRCLK  => I2S_LRCLK,
    I2S_DACSD  => I2S_DACSD,
    I2S_ADCSD  => I2S_ADCSD,
        
        -- GPIF Signals
    GPIF_CLK   => GPIF_CLK,
    GPIF_SLCS  => GPIF_SLCS,
    GPIF_DATA  => GPIF_DATA,
    GPIF_ADDR  => GPIF_ADDR,
    GPIF_SLRD  => GPIF_SLRD,
    GPIF_SLOE  => GPIF_SLOE,
    GPIF_SLWR  => GPIF_SLWR,
    GPIF_FLAGA => GPIF_FLAGA,     
    GPIF_FLAGB => GPIF_FLAGB,
    GPIF_PKTEND=> GPIF_PKTEND,
        
        -- Tempo signals
    TEMPO_SW   => TEMPO_SW,
    TEMPO_LED  => TEMPO_LED,
    
    -- LCD signals
    LCD_SDO => LCD_SDO,
    LCD_TE  => LCD_TE
);

    
-- Clock process definitions( clock with 50% duty cycle is generated here.
clk100_process: process
begin
clk100 <= '0';
wait for clk100_period/2;  --for 0.5 ns signal is '0'.
clk100 <= '1';
wait for clk100_period/2;  --for next 0.5 ns signal is '1'.
end process;

samplegen_clk_process: process
begin
samplegen_clk <= '0';
wait for samplegen_clk_period/2;  --for 0.5 ns signal is '0'.
samplegen_clk <= '1';
wait for samplegen_clk_period/2;  --for next 0.5 ns signal is '1'.
end process;

sampleproc: process(samplegen_clk) begin
if rising_edge(samplegen_clk) then
    NEXT_SAMPLEPRODUCE_COUNTER <= NEXT_SAMPLEPRODUCE_COUNTER + 1;
    if NEXT_SAMPLEPRODUCE_COUNTER = NEXT_SAMPLEPRODUCE_COUNTER_MAX - 1 then
        NEXT_SAMPLEPRODUCE_COUNTER <= 0;
        USB_RDY_TO_SEND_PACKET <= '1';
    elsif outbuffersamplecount /= 0 then
        USB_RDY_TO_SEND_PACKET <= '0';
    end if;
end if;
end process;

gpifproc: process(GPIF_CLK) begin
    if rising_edge(GPIF_CLK) then
   
        BPcount  <= BPcount + 1;
        SOFcount <= SOFcount + 1;
        OSEVENTcount <= OSEVENTcount + 1;
        -- every millisecond, indicate SOF
        if SOFcount = 48000 then
            SOF <= '1';
            SOFcount <= 0;
        end if;
        if BPcount >= 48000 and (BPSENT < 4)  then
            BPSENT <= BPSENT + 1;
            BP <= '1';
            BPcount <= 0;
        end if;
        if OSEVENTcount = 12000  then
            OSEVENT <= '1';
        end if;
        
        Z00_TESTSAW  <= ZN1_TESTSAW;
        Z02_EXSAMPLE <= Z01_EXSAMPLE;
        -- technically reaching across clock domains, doesnt matter in simulation
        SAMPLEPROD_last <= USB_RDY_TO_SEND_PACKET;
        
        RWSTATE <= 0;
        -- record writes to fifo for debug purposes
        if GPIF_SLWR = '0' then
            RWSTATE <= RWSTATE+1;
            CHANNELFIFO(currchan, writeptr) <= GPIF_DATA(7 downto 0) & GPIF_DATA(15 downto 8);
            thisRead <= GPIF_DATA(7 downto 0) & GPIF_DATA(15 downto 8);
            if currchan = 0 then
                currchan <= 1;
            else
                currchan <= 0;
                writeptr <= (writeptr + 1) mod fifolength;
            end if;
        end if;

        ZN1_GPIF_FLAGA <= ZN2_GPIF_FLAGA;
        GPIF_FLAGA     <= ZN1_GPIF_FLAGA;
        
        if outbuffersamplecount = 0 then
            ZN2_GPIF_FLAGA <= '0';
            -- on rising edge of USB_RDY_TO_SEND_PACKET, increase outbuffersamplecount by 64
            if USB_RDY_TO_SEND_PACKET = '1' and SAMPLEPROD_last = '0' then
                outbuffersamplecount <= outbuffersamplecount + (BYTES_PER_SAMPLE_XFER/BYTES_PER_SAMPLE);
            end if;
        else
            ZN2_GPIF_FLAGA <= '1';
            outbuffersamplecount <= outbuffersamplecount-1;
        end if;
        
        SAMPLEREAD_COUNT <= SAMPLEREAD_COUNT + 1;
        -- trigger sample read every sample
        -- thisclk / samplerate
        if SAMPLEREAD_COUNT = 48000000/48000 then
            SAMPLEREAD_COUNT <= 0;
            readptr <= (readptr + 1) mod fifolength;
        end if;
        
        -- supply a sample or parameter, depending on request address
        if(GPIF_SLRD = '0') then
            RWSTATE <= RWSTATE + 1;
            if GPIF_ADDR = GPIFADDR_READPARAM then
                -- always increase the param counter
                ZN1_PARAMPTR <= (ZN1_PARAMPTR+1) mod 8;
                if ZN1_PARAMPTR = 7 then
                    if INIT_PARAMS = '1' then
                        -- increase the parameter read count
                        ZN1_PN <= (ZN1_PN + 1);
                        -- at the end of init, lower flag, declare end of init, and reset params ptr
                        if ZN1_PN = initparamcount-1 then
                            GPIF_FLAGB <= '0';  
                            INIT_PARAMS<= '0';
                            ZN1_PN <= 0;
                            Z00_PN <= 0;
                        end if;
                    else
                        -- lower FLAGB
                        GPIF_FLAGB <= '0';  
                    end if;
                    -- if we just sent SOF, lower SOF flag  
                    if Z00_PN = SOF_ADDR then
                        SOF <= '0';    
                    end if;
                    -- if we just sent BP, lower BP flag
                    if Z00_PN = BP_ADDR then
                        BP <= '0';    
                    end if;
                    -- if we just sent OSEVENT, lower OSEVENT flag
                    if Z00_PN = OSEVENT_ADDR then
                        OSEVENT <= '0';    
                    end if;
                end if;
            else
                ZN1_TESTSAW <= ZN1_TESTSAW+1;
            end if;
        end if;
        
        Z00_PARAMPTR <= ZN1_PARAMPTR;
        Z00_PN  <= ZN1_PN;
        
        -- if SOF requested and there are is no param waiting
        if SOF = '1' and GPIF_FLAGB = '0' then
            ZN1_PN <= SOF_ADDR;
            GPIF_FLAGB <= '1';        
        -- if BP requested and there are is no param waiting
        elsif BP = '1' and GPIF_FLAGB = '0' then
            ZN1_PN <= BP_ADDR;
            GPIF_FLAGB <= '1';
        -- if OS_EVENT requested and there are is no param waiting
        elsif OSEVENT = '1' and GPIF_FLAGB = '0' then
            ZN1_PN <= OSEVENT_ADDR;
            GPIF_FLAGB <= '1';
        end if;
           
        
        if(GPIF_SLOE = '1') then
            GPIF_DATA <= (others=>'Z');   
        else
            if GPIF_ADDR = GPIFADDR_READPARAM then
                -- read from init params if appropriate
                if INIT_PARAMS = '1' then
                    case Z00_PARAMPTR is 
                    when 0 => 
                        GPIF_DATA <= "1" & STD_LOGIC_VECTOR(PN(Z00_PN));
                    when 1 => 
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(INSTNO(Z00_PN));
                    when 2 =>   
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(VOICENO(Z00_PN));
                    when 3 =>   
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(A1(Z00_PN));
                    when 4 =>
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(A0(Z00_PN));
                    when 5 =>
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(OP(Z00_PN)) & "00" & STD_LOGIC_VECTOR(PL(Z00_PN)(35 downto 30));
                    when 6 =>
                        GPIF_DATA <= '0' & STD_LOGIC_VECTOR(PL(Z00_PN)(29 downto 15));
                    when others =>
                        GPIF_DATA <= '0' & STD_LOGIC_VECTOR(PL(Z00_PN)(14 downto 0));
                    end case;
                else
                -- otherwise read from late params
                    case Z00_PARAMPTR is 
                    when 0 => 
                        GPIF_DATA <= "1" & STD_LOGIC_VECTOR(L_PN(Z00_PN));
                    when 1 => 
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(L_INSTNO(Z00_PN));
                    when 2 =>   
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(L_VOICENO(Z00_PN));
                    when 3 =>   
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(L_A1(Z00_PN));
                    when 4 =>
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(L_A0(Z00_PN));
                    when 5 =>
                        GPIF_DATA <= "0" & STD_LOGIC_VECTOR(L_OP(Z00_PN)) & "00" & STD_LOGIC_VECTOR(L_PL(Z00_PN)(35 downto 30));
                    when 6 =>
                        GPIF_DATA <= '0' & STD_LOGIC_VECTOR(L_PL(Z00_PN)(29 downto 15));
                    when others =>
                        GPIF_DATA <= '0' & STD_LOGIC_VECTOR(L_PL(Z00_PN)(14 downto 0));
                    end case;
                end if;
            else
                GPIF_DATA <= std_logic_vector(Z00_TESTSAW(7 downto 0)) & std_logic_vector(Z00_TESTSAW(15 downto 8));
            end if;
        end if;
    end if;
end process;

fmtestproc: process
begin

-- set voice shift
PN(0) <= to_unsigned(P_VOICESHIFT, 15); -- paramtype
PL(0) <= to_unsigned(0, RAM_WIDTH36); -- 0

-- then unison count
PN(1) <= to_unsigned(P_VOICE_UNISON, 15); -- paramtype
PL(1) <= to_unsigned(3, RAM_WIDTH36); -- 0 

-- set voice shift to 2
PN(2) <= to_unsigned(P_VOICESHIFT, 15); -- paramtype
PL(2) <= to_unsigned(4, RAM_WIDTH36);

-- claim VOICETAG0 0
PN(3) <= to_unsigned(P_VOICE_SPAWN, 15); -- paramtype

-- claim VOICETAG0 7
PN(4) <= to_unsigned(P_VOICE_SPAWN, 15); -- paramtype
VOICENO(4)<= VOICETAG1; -- VOICENUM


-- set rate of increment change
PN(21) <= to_unsigned(P_VOICE_PORTRATE, 15); -- paramtype
PL(21) <= to_unsigned(2**21, RAM_WIDTH36);

-- set increment
PN(22) <= to_unsigned(P_VOICE_INC, 15); -- paramtype
PL(22) <= to_unsigned(2**18, RAM_WIDTH36);

-- set increment of next voice
PN(23) <= to_unsigned(P_VOICE_INC, 15); -- paramtype
VOICENO(23)<= VOICETAG1; -- VOICENUM
PL(23) <= to_unsigned(2**17, RAM_WIDTH36);

-- modamp: none
-- feedback: none
    
-- set oscvolume to full
PN(24) <= to_unsigned(P_OSC_VOLUME, 15); -- paramtype
PL(24) <= to_unsigned(2**16, RAM_WIDTH36);
    
--set first envelope draw to os 0
PN(25) <= to_unsigned(P_VOICE_ENV, 15); -- paramtype
OP(25)(6 downto 3) <= OPTIONS_DRAW; 
A1(25) <= to_unsigned(0, 15); -- envnum
PL(25) <= to_unsigned(DRAW_OS_I, RAM_WIDTH36);

--set second envelope to OS 0 
PN(26) <= to_unsigned(P_VOICE_ENV, 15); -- paramtype
A1(26) <= to_unsigned(1, 15); -- envnum
-- set to full
OP(26) <= ALL_VOICES;
PL(26) <= to_unsigned(2**16, RAM_WIDTH36);

--set third envelope to full amplitude, fixed, all voices
PN(27) <= to_unsigned(P_VOICE_ENV, 15); -- paramtype
A1(27) <= to_unsigned(2, 15); -- envnum
OP(27) <= ALL_VOICES;
PL(27) <= to_unsigned(2**16, RAM_WIDTH36);

--set fourth envelope to full amplitude, fixed, all voices
PN(28) <= to_unsigned(P_VOICE_ENV, 15); -- paramtype
A1(28) <= to_unsigned(3, 15); -- envnum
OP(28) <= ALL_VOICES;
PL(28) <= to_unsigned(2**16, RAM_WIDTH36);

-- channel 0 (left) pan value: full, all voices
PN(29) <= to_unsigned(P_VOICE_PAN, 15); -- paramtype
A1(29) <= to_unsigned(0, 15); -- channel
A0(29) <= to_unsigned(0, 15); -- panmod
OP(29) <= ALL_VOICES;
PL(29) <= to_unsigned(2**16, RAM_WIDTH36); -- val: full
PL(29) <= to_unsigned(0, RAM_WIDTH36); -- val: zero

-- channel 0 (left) pan value: full
PN(30) <= to_unsigned(P_VOICE_PAN, 15); -- paramtype
A1(30) <= to_unsigned(0, 15); -- channel
A0(30) <= to_unsigned(1, 15); -- panmod
OP(30) <= ALL_VOICES;
PL(30) <= to_unsigned(2**16, RAM_WIDTH36); -- val: full

-- channel 1 (right) pan value: full
PN(31) <= to_unsigned(P_VOICE_PAN, 15); -- paramtype
A1(31) <= to_unsigned(1, 15); -- channel
A0(31) <= to_unsigned(0, 15); -- panmod
PL(31) <= to_unsigned(2**16, RAM_WIDTH36); -- val: full

-- channel 1 (right) pan value: full
PN(32) <= to_unsigned(P_VOICE_PAN, 15); -- paramtype
A1(32) <= to_unsigned(1, 15); -- channel
A0(32) <= to_unsigned(1, 15); -- panmod
PL(32) <= to_unsigned(2**16, RAM_WIDTH36); -- val: full

-- set instvol vals and draw
-- instval mod 0 is set fixed
PN(33) <= to_unsigned(P_INSTVOL, 15); -- paramtype
A1(33) <= to_unsigned(0, 15); -- instmod
PL(33) <= to_unsigned(2**16, RAM_WIDTH36); -- val: full

PN(34) <= to_unsigned(P_INSTVOL, 15); -- paramtype
A1(34) <= to_unsigned(1, 15); -- instmod
PL(34) <= to_unsigned(2**16, RAM_WIDTH36); -- val: full

-- filter params(0):
-- set F to roughly 1000Hz
PN(35) <= to_unsigned(P_VOICE_FILT_F, 15); -- paramtype
A1(35) <= to_unsigned(0, 15); -- pole
-- if F = 1, the corner frequency is f*oversamplecount*fs/2pi = 30557.75
-- where F is fixed point, 2**16 == 1
-- cf = f*osc*fs/2pi
-- f = cf*2pi/osc*fs
-- so if cf = 1000Hz
-- f = 2**16*1000*2pi/(4*48000) = 2145
--PL(15) <= to_unsigned(2145, RAM_WIDTH36); -- 1000 Hz
OP(35) <= ALL_VOICES;
PL(35) <= to_unsigned(OSNUM, RAM_WIDTH36);

-- set draw to OS 1
PN(36) <= to_unsigned(P_VOICE_FILT_F, 15); -- paramtype
A1(36) <= to_unsigned(0, 15); -- pole
OP(36) <= ALL_VOICES;
PL(36) <= to_unsigned(DRAW_OS_I, RAM_WIDTH36);


-- set Q to butterworth Q
PN(37) <= to_unsigned(P_VOICE_FILT_Q, 15); -- paramtype
A1(37) <= to_unsigned(0, 15); -- pole
-- q is on scale 2**14 = 1
-- -sqrt(2) is butterworth
-- so q = -2**14*sqrt(2) = -23170
PL(37)(17 downto 0) <= unsigned(to_signed(-23170, 18)); -- -sqrt(2) for butterworth

-- set the type to lowpass
PN(38) <= to_unsigned(P_VOICE_FILT_TYP, 15); -- paramtype
A1(38) <= to_unsigned(0, 15); -- pole
PL(38) <= to_unsigned(FTYPE_NONE_I, RAM_WIDTH36);

-- filter params(1):
-- set F to roughly 1000Hz
PN(39) <= to_unsigned(P_VOICE_FILT_F, 15); -- paramtype
A1(39) <= to_unsigned(1, 15); -- pole
--PL(18) <= to_unsigned(2145, RAM_WIDTH36); -- roughly 1000 Hz
PL(39) <= to_unsigned(0, RAM_WIDTH36); -- 0 Hz

-- set Q to butterworth Q
PN(40) <= to_unsigned(P_VOICE_FILT_Q, 15); -- paramtype
A1(40) <= to_unsigned(1, 15); -- pole
--PL19)(17 downto 0) <= unsigned(to_signed(-23170, 18)); -- sqrt(2) for butterworth
PL(40)(17 downto 0) <= unsigned(to_signed(0, 18)); -- 0

-- set the type to lowpass
PN(41) <= to_unsigned(P_VOICE_FILT_TYP, 15); -- paramtype
A1(41) <= to_unsigned(1, 15); -- pole
PL(41) <= to_unsigned(FTYPE_NONE_I, RAM_WIDTH36);

-- oneSHOT rate
-- let the rate be, in all stages, 4 times the DIVrate
PN(42) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
A1(42) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(42) <= to_unsigned(0, 15); -- stage
PL(42) <= DOSRATE;

PN(43) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
A1(43) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(43) <= to_unsigned(1, 15); -- stage
PL(43) <= DOSRATE;

-- except the sustain stage, which shall be 0 until release
PN(44) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
A1(44) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(44) <= to_unsigned(2, 15); -- stage
PL(44) <= DOSRATE;

PN(45) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
A1(45) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(45) <= to_unsigned(3, 15); -- stage
PL(45) <= DOSRATE;

-- oneSHOT rate draws
-- let the draw be, in all stages, the beat
--PN(46) <= to_unsigned(P_ONESHOT_RATE_D, 15); -- paramtype
--A1(46) <= to_unsigned(OSNUM, 15); -- oneSHOT
--A0(46) <= to_unsigned(0, 15); -- stage
--PL(46) <= to_unsigned(DRAW_BEAT_I, RAM_WIDTH36);

--PN(47) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
--A1(47) <= to_unsigned(OSNUM, 15); -- oneSHOT
--A0(47) <= to_unsigned(1, 15); -- stage
--PL(47) <= to_unsigned(DRAW_BEAT_I, RAM_WIDTH36);

--PN(48) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
--A1(48) <= to_unsigned(OSNUM, 15); -- oneSHOT
--A0(48) <= to_unsigned(2, 15); -- stage
--PL(48) <= to_unsigned(DRAW_BEAT_I, RAM_WIDTH36);

--PN(49) <= to_unsigned(P_ONESHOT_RATE, 15); -- paramtype
--A1(49) <= to_unsigned(OSNUM, 15); -- oneSHOT
--A0(49) <= to_unsigned(3, 15); -- stage
--PL(49) <= to_unsigned(DRAW_BEAT_I, RAM_WIDTH36);


-- alternate os startpoints between 0 and max
PN(55) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 15); -- paramtype
A1(55) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(55) <= to_unsigned(0, 15); -- stage
PL(55) <= to_unsigned(0, RAM_WIDTH36);

PN(56) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 15); -- paramtype
A1(56) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(56) <= to_unsigned(1, 15); -- stage
PL(56) <= to_unsigned(2**16, RAM_WIDTH36);

PN(57) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 15); -- paramtype
A1(57) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(57) <= to_unsigned(2, 15); -- stage
PL(57) <= to_unsigned(2**15, RAM_WIDTH36);

PN(58) <= to_unsigned(P_ONESHOT_STARTPOINT_Y, 15); -- paramtype
A1(58) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(58) <= to_unsigned(3, 15); -- stage
PL(58) <= to_unsigned(0, RAM_WIDTH36);

-- midpoints always quarter full
PN(59) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 15); -- paramtype
A1(59) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(59) <= to_unsigned(0, 15); -- stage
PL(59) <= to_unsigned(2**15, RAM_WIDTH36);

PN(60) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 15); -- paramtype
A1(60) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(60) <= to_unsigned(1, 15); -- stage
PL(60) <= to_unsigned(2**15, RAM_WIDTH36);

PN(61) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 15); -- paramtype
A1(61) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(61) <= to_unsigned(2, 15); -- stage
PL(61) <= to_unsigned(2**5, RAM_WIDTH36);

PN(62) <= to_unsigned(P_ONESHOT_MIDPOINT_Y, 15); -- paramtype
A1(62) <= to_unsigned(OSNUM, 15); -- oneSHOT
A0(62) <= to_unsigned(3, 15); -- stage
PL(62) <= to_unsigned(0, RAM_WIDTH36);

-- establish one delay line (on two channels)
-- the remainder are passthrough by default
-- on channel 0:
-- length : 512 samples
PN(63) <= to_unsigned(P_DELAY_SAMPLES, 15); -- paramtype
A1(63) <= to_unsigned(0, 15); -- channel
A0(63) <= to_unsigned(0, 15); -- tapno
-- set delay to 700 samples, or roughly 10 mS
PL(63) <= to_unsigned(100, RAM_WIDTH36);

----------------------------------
-- set all 3 forward gains to full
----------------------------------
PN(64) <= to_unsigned(P_SAP_FORWARD_GAIN, 15); -- paramtype
A1(64) <= to_unsigned(0, 15); -- tapno
A0(64) <= to_unsigned(0, 15); -- unused
--PL(34) <= "00101111111111111111"; -- -.5
PL(64) <= to_unsigned(2**16, RAM_WIDTH36);

PN(65) <= to_unsigned(P_SAP_FORWARD_GAIN, 15); -- paramtype
A1(65) <= to_unsigned(1, 15); -- tapno
A0(65) <= to_unsigned(0, 15); -- unused
PL(65) <= to_unsigned(2**16, RAM_WIDTH36); -- 1

PN(66) <= to_unsigned(P_SAP_FORWARD_GAIN, 15); -- paramtype
A1(66) <= to_unsigned(2, 15); -- tapno
A0(66) <= to_unsigned(0, 15); -- unused
PL(66) <= to_unsigned(2**16, RAM_WIDTH36); -- 1

------------------------
-- END FORWARD GAINS
------------------------

PN(72) <= to_unsigned(P_SAP_COLOR_GAIN, 15); -- paramtype
A1(72) <= to_unsigned(0, 15); -- channel
A0(72) <= to_unsigned(0, 15); -- tapno
--PL(34) <= "00010111111111111111"; -- .75
--PL(51) <= "00011111111111111111"; -- 1
--PL(42) <= to_unsigned(2**16, RAM_WIDTH36); -- 0
PL(72) <= to_unsigned(0, RAM_WIDTH36); -- 0

-- set osc shift
PN(73) <= to_unsigned(P_NULL, 15); -- paramtype
PL(73) <= to_unsigned(0, RAM_WIDTH36); -- 0


-- set inst shift
PN(74) <= to_unsigned(P_INSTSHIFT, 15); -- paramtype
PL(74) <= to_unsigned(0, RAM_WIDTH36); -- 0
-- polylfos: unused
-- detune draw/val: default

-- set tempo
PN(75) <= to_unsigned(P_TEMPO, 15); -- paramtype
PL(75) <= to_unsigned(2**17, PL(0)'length); -- 1

-- set measure count
PN(76) <= to_unsigned(P_NULL, 15); -- paramtype
PL(76) <= to_unsigned(16, PL(0)'length); -- 16

-- set beat count
PN(77) <= to_unsigned(P_BEATCOUNT, 15); -- paramtype
PL(77) <= to_unsigned(4, PL(0)'length); -- 4


-- set harmonicity to fifths
PN(79) <= to_unsigned(P_OSC_HARMONICITY, 15); -- paramtype
INSTNO(79) <= INSTNUM; -- VOICENUM
OP(79) <= ALL_VOICES;
PL(79) <= (others=>'0');

-- set harmonicity alpha to 2**15 (1/2)
PN(80) <= to_unsigned(P_OSC_HARMONICITY_A, 15); -- paramtype
OP(80) <= ALL_VOICES;
--PL(60) <= to_unsigned(2**15, RAM_WIDTH36);
PL(80) <= to_unsigned(2**16, RAM_WIDTH36);

-- set osc0 detune to 1
PN(81) <= to_unsigned(P_OSC_DETUNE, 15); -- paramtype
PL(81) <= to_unsigned(2**14 + 2**11, RAM_WIDTH36); -- 1

-- set osc0detune to 1
PN(82) <= to_unsigned(P_OSC_DETUNE, 15); -- paramtype
VOICENO(82) <= VOICETAG1; -- VOICENUM
A1(82) <= OSCNUM + 1; -- osc
PL(82) <= to_unsigned(2**14 + 2**11, RAM_WIDTH36); -- 1

-- set tempo to 400
PN(83) <= to_unsigned(P_TEMPO, 15); -- paramtype
PL(83) <= to_unsigned(400, RAM_WIDTH36);

-- ringmod osc 0 with 1
--PN(84) <= to_unsigned(P_OSC_RINGMOD, 15); -- paramtype
--A0(84) <= to_unsigned(0, 15); -- unused
----PL(64) <= to_unsigned(2, RAM_WIDTH36);
--PL(84) <= to_unsigned(0, RAM_WIDTH36);

-- down ratio
PN(85) <= to_unsigned(P_VOICE_UNISON_DET, 15); -- paramtype
A1(85) <= to_unsigned(0, 15); -- N/A
PL(85)(17 downto 0) <= "001111111111011010"; -- 0

-- up ratio
PN(86) <= to_unsigned(P_VOICE_UNISON_DET, 15); -- paramtype
A1(86) <= to_unsigned(1, 15); -- N/A
PL(86)(17 downto 0) <= "010000000000100101"; -- 0

-- detune midpoint
PN(87) <= to_unsigned(P_VOICE_UNISON_MIDPOINT, 15); -- paramtype
PL(87) <= to_unsigned(2**14, RAM_WIDTH36); -- 0



-- set divsperstage
PN(90) <= to_unsigned(P_ONESHOT_DIVSPERSTAGE, 15); -- paramtype
PL(90) <= to_unsigned(8, RAM_WIDTH36);

-- set oscvolume to full
PN(91) <= to_unsigned(P_OSC_VOLUME, 15); -- paramtype
VOICENO(91) <= VOICETAG1; -- VOICENUM
PL(91) <= to_unsigned(2**16, RAM_WIDTH36);

-- beatpulse
PN(92) <= to_unsigned(P_BEATPULSE, 15); -- paramtype
PL(92) <= to_unsigned(1, RAM_WIDTH36); -- 0
   
-- reset LCD
PN(93) <= to_unsigned(P_LCD_RESET, 15); -- paramtype
   
-- send command
PN(94) <= to_unsigned(P_LCD_COMMAND, 15); -- paramtype
PL(94) <= to_unsigned((2**22) + 5555, RAM_WIDTH36); -- 0
   
-- send data
PN(95) <= to_unsigned(P_LCD_DATA, 15); -- paramtype
PL(95) <= to_unsigned(5555, RAM_WIDTH36); -- 0
   
-- set base color
PN(96) <= to_unsigned(P_LCD_SETCOLOR, 15); -- paramtype
PL(96)(20 downto 0) <= unsigned(COLOR_BASE) & to_unsigned(2**18 * 1 / 4, 18); -- 0

-- set dBx
PN(97) <= to_unsigned(P_LCD_SETCOLOR, 15); -- paramtype
PL(97)(20 downto 0) <= unsigned(COLOR_dBx) & to_unsigned(20, 18);

-- set dBy
PN(98) <= to_unsigned(P_LCD_SETCOLOR, 15); -- paramtype
PL(98)(20 downto 0) <= unsigned(COLOR_dBy) & to_unsigned(10, 18);

-- set width
PN(99) <= to_unsigned(P_LCD_SETCOLUMN, 15); -- paramtype
PL(99)(17 downto 0) <= to_unsigned(2, 18);

-- set height
PN(100) <= to_unsigned(P_LCD_SETROW, 15); -- paramtype
PL(100)(17 downto 0) <= to_unsigned(2, 18);

-- draw alternating squares
PN(101) <= to_unsigned(P_LCD_DRAWSQUARES, 15); -- paramtype
PL(101)(17 downto 0) <= "101010101010101010"; -- 0

-- NOP bc i dont feel like fixing indexing problem
PN(102) <= to_unsigned(P_NULL, 15); -- paramtype
-- that concludes init params


-- set the late parameters
-- set SOF param
L_PN(SOF_ADDR) <= to_unsigned(P_SOF, 15); -- paramtype
L_PL(SOF_ADDR) <= to_unsigned(0, RAM_WIDTH36); -- 0

-- and beatpulse
L_PN(BP_ADDR) <= to_unsigned(P_BEATPULSE, 15); -- paramtype
L_PL(BP_ADDR) <= to_unsigned(0, RAM_WIDTH36); -- 0

-- and the SETSTAGE late command
L_PN(OSEVENT_ADDR) <= to_unsigned(P_ONESHOT_STAGESET, 15); -- paramtype
L_PL(OSEVENT_ADDR) <= to_unsigned(2, RAM_WIDTH36); -- to stage 2

wait;

end process;
end Behavioral;
