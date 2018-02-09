--------------------------------------------------------------------------
-- First_tf.vhd
--
-- A simple text fixture example for getting started with FrontPanel
-- simulation.  This sample connects the top-level signals from First.vhd
-- to a call system that, when integrated with Opal Kelly simulation
-- libraries, mimics the functionality of FrontPanel.  Listed below are
-- the procedure and functions that can be called.  They are designed to
-- replicate calls made from the PC via FrontPanel API, Python, Java, DLL,
-- etc.
--
--------------------------------------------------------------------------
-- Copyright (c) 2005-2015 Opal Kelly Incorporated
-- $Rev$ $Date$
--------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_textio.all;

library STD;
use std.textio.all;

use work.mappings.all;
use work.parameters.all;

entity FIRST_TEST is
end FIRST_TEST;

architecture sim of FIRST_TEST is

	component First port (
		okUH        : in    std_logic_vector(4 downto 0);
		okHU        : out   std_logic_vector(2 downto 0);
		okUHU       : inout std_logic_vector(31 downto 0);
		led         : out   std_logic_vector(7 downto 0));
	end component;

	signal okUH       : std_logic_vector(4 downto 0) := b"00000";
	signal okHU       : std_logic_vector(2 downto 0);
	signal okUHU      : std_logic_vector(31 downto 0);
	signal okAA       : std_logic;
	signal led        : std_logic_vector(7 downto 0);
	signal hi_clk     : std_logic;
	signal hi_drive   : std_logic := '0';
	signal hi_cmd     : std_logic_vector(2 downto 0) := b"000";
	signal hi_busy    : std_logic;
	signal hi_datain  : std_logic_vector(31 downto 0) := x"0000_0000";
	signal hi_dataout : std_logic_vector(31 downto 0) := x"0000_0000";
	signal sys_clkp   : std_logic;
	signal sys_clkn   : std_logic;
	signal sys_clk    : std_logic := '0';

	constant tCK      : time := 5 ns;
	constant Tsys_clk : time := 5 ns; --Varies for different devices
	
--------------------------------------------------------------------------
-- Begin functional body
--------------------------------------------------------------------------
begin

	dut : First port map (
		okUH => okUH,
		okHU => okHU,
		okUHU => okUHU,
		led => led
	);

	okUH(0)          <= hi_clk;
	okUH(1)          <= hi_drive;
	okUH(4 downto 2) <= hi_cmd;
	hi_datain        <= okUHU;
	hi_busy          <= okHU(0);
	okUHU            <= hi_dataout when (hi_drive = '1') else (others =>'Z');
	
	-- Clock Generation Process
	hi_clk_gen : process is
	begin
		hi_clk <= '0';
		wait for tCk;
		hi_clk <= '1'; 
		wait for tCk; 
	end process hi_clk_gen;

	sys_clk_gen : process is
	begin
		sys_clk <= '0';
		sys_clkp <= '0';
		sys_clkn <= '1';
		wait for Tsys_clk;
		sys_clk <= '1';
		sys_clkp <= '1';
		sys_clkn <= '0'; 
		wait for Tsys_clk; 
	end process sys_clk_gen;

	--------------------------------------------------------------------------
	-- Begin Simulation Process 
	--------------------------------------------------------------------------
	sim_process : process is

	--<<<<<<<<<<<<<<<<<<< OKHOSTCALLS START PASTE HERE >>>>>>>>>>>>>>>>>>>>-- 
	
	-----------------------------------------------------------------------
	-- User defined data for pipe and register procedures
	-----------------------------------------------------------------------
	variable BlockDelayStates : integer := 5;    -- REQUIRED: # of clocks between blocks of pipe data
	variable ReadyCheckDelay  : integer := 5;    -- REQUIRED: # of clocks before block transfer before
	                                             --    host interface checks for ready (0-255)
	variable PostReadyDelay   : integer := 5;    -- REQUIRED: # of clocks after ready is asserted and
	                                             --    check that the block transfer begins (0-255)
	variable pipeInSize       : integer := 1024; -- REQUIRED: byte (must be even) length of default
                                               --    PipeIn; Integer 0-2^32
	variable pipeOutSize      : integer := 1024; -- REQUIRED: byte (must be even) length of default
                                               --    PipeOut; Integer 0-2^32
	variable registerSetSize  : integer := 32;   -- Size of array for register set commands.
                                                                                            
	-----------------------------------------------------------------------
	-- Required data for procedures and functions
	-----------------------------------------------------------------------
	-- If you require multiple pipe arrays, you may create more arrays here
	-- duplicate the desired pipe procedures as required, change the names
	-- of the duplicated procedure to a unique identifiers, and alter the
	-- pipe array in that procedure to your newly generated arrays here.
	type PIPEIN_ARRAY is array (0 to pipeInSize - 1) of std_logic_vector(7 downto 0);
	variable pipeIn   : PIPEIN_ARRAY;

	type PIPEOUT_ARRAY is array (0 to pipeOutSize - 1) of std_logic_vector(7 downto 0);
	variable pipeOut  : PIPEOUT_ARRAY;

	type STD_ARRAY is array (0 to 31) of std_logic_vector(31 downto 0);
	variable WireIns    :  STD_ARRAY; -- 32x32 array storing WireIn values
	variable WireOuts   :  STD_ARRAY; -- 32x32 array storing WireOut values 
  variable Triggered  :  STD_ARRAY; -- 32x32 array storing IsTriggered values
	
	type REGISTER_ARRAY is array (0 to registerSetSize - 1) of std_logic_vector(31 downto 0);
	variable u32Address  : REGISTER_ARRAY;
	variable u32Data     : REGISTER_ARRAY;
	variable u32Count    : std_logic_vector(31 downto 0);
	variable ReadRegisterData    : std_logic_vector(31 downto 0);
	
	constant DNOP                  : std_logic_vector(2 downto 0) := "000";
	constant DReset                : std_logic_vector(2 downto 0) := "001";
	constant DWires                : std_logic_vector(2 downto 0) := "010";
	constant DUpdateWireIns        : std_logic_vector(2 downto 0) := "001";
	constant DUpdateWireOuts       : std_logic_vector(2 downto 0) := "010";
	constant DTriggers             : std_logic_vector(2 downto 0) := "011";
	constant DActivateTriggerIn    : std_logic_vector(2 downto 0) := "001";
	constant DUpdateTriggerOuts    : std_logic_vector(2 downto 0) := "010";
	constant DPipes                : std_logic_vector(2 downto 0) := "100";
	constant DWriteToPipeIn        : std_logic_vector(2 downto 0) := "001";
	constant DReadFromPipeOut      : std_logic_vector(2 downto 0) := "010";
	constant DWriteToBlockPipeIn   : std_logic_vector(2 downto 0) := "011";
	constant DReadFromBlockPipeOut : std_logic_vector(2 downto 0) := "100";
	constant DRegisters            : std_logic_vector(2 downto 0) := "101";
	constant DWriteRegister        : std_logic_vector(2 downto 0) := "001";
	constant DReadRegister         : std_logic_vector(2 downto 0) := "010";
	constant DWriteRegisterSet     : std_logic_vector(2 downto 0) := "011";
	constant DReadRegisterSet      : std_logic_vector(2 downto 0) := "100";

	-----------------------------------------------------------------------
	-- FrontPanelReset
	-----------------------------------------------------------------------
	procedure FrontPanelReset is
		variable i : integer := 0;
		variable msg_line           : line;
	begin
			for i in 31 downto 0 loop
				WireIns(i) := (others => '0');
				WireOuts(i) := (others => '0');
				Triggered(i) := (others => '0');
			end loop;
			wait until (rising_edge(hi_clk)); hi_cmd <= DReset;
			wait until (rising_edge(hi_clk)); hi_cmd <= DNOP;
			wait until (hi_busy = '0');
	end procedure FrontPanelReset;

	-----------------------------------------------------------------------
	-- SetWireInValue
	-----------------------------------------------------------------------
	procedure SetWireInValue (
		ep   : in  std_logic_vector(7 downto 0);
		val  : in  std_logic_vector(31 downto 0);
		mask : in  std_logic_vector(31 downto 0)) is
		
		variable tmp_slv32 :     std_logic_vector(31 downto 0);
		variable tmpI      :     integer;
	begin
		tmpI := CONV_INTEGER(ep);
		tmp_slv32 := WireIns(tmpI) and (not mask);
		WireIns(tmpI) := (tmp_slv32 or (val and mask));
	end procedure SetWireInValue;

	-----------------------------------------------------------------------
	-- GetWireOutValue
	-----------------------------------------------------------------------
	impure function GetWireOutValue (
		ep : std_logic_vector) return std_logic_vector is
		
		variable tmp_slv32 : std_logic_vector(31 downto 0);
		variable tmpI      : integer;
	begin
		tmpI := CONV_INTEGER(ep);
		tmp_slv32 := WireOuts(tmpI - 16#20#);
		return (tmp_slv32);
	end GetWireOutValue;

	-----------------------------------------------------------------------
	-- IsTriggered
	-----------------------------------------------------------------------
	impure function IsTriggered (
		ep   : std_logic_vector;
		mask : std_logic_vector(31 downto 0)) return BOOLEAN is
		
		variable tmp_slv32   : std_logic_vector(31 downto 0);
		variable tmpI        : integer;
		variable msg_line    : line;
	begin
		tmpI := CONV_INTEGER(ep);
		tmp_slv32 := (Triggered(tmpI - 16#60#) and mask);

		if (tmp_slv32 >= 0) then
			if (tmp_slv32 = 0) then
				return FALSE;
			else
				return TRUE;
			end if;
		else
			write(msg_line, STRING'("***FRONTPANEL ERROR: IsTriggered mask 0x"));
			hwrite(msg_line, mask);
			write(msg_line, STRING'(" covers unused Triggers"));
			writeline(output, msg_line);
			return FALSE;        
		end if;     
	end IsTriggered;

	-----------------------------------------------------------------------
	-- UpdateWireIns
	-----------------------------------------------------------------------
	procedure UpdateWireIns is
		variable i : integer := 0;
	begin
		wait until (rising_edge(hi_clk)); hi_cmd <= DWires; 
		wait until (rising_edge(hi_clk)); hi_cmd <= DUpdateWireIns; 
		wait until (rising_edge(hi_clk));
		hi_drive <= '1'; 
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP; 
		for i in 0 to 31 loop
			hi_dataout <= WireIns(i);  wait until (rising_edge(hi_clk)); 
		end loop;
		wait until (hi_busy = '0');  
	end procedure UpdateWireIns;
   
	-----------------------------------------------------------------------
	-- UpdateWireOuts
	-----------------------------------------------------------------------
	procedure UpdateWireOuts is
		variable i : integer := 0;
	begin
		wait until (rising_edge(hi_clk)); hi_cmd <= DWires; 
		wait until (rising_edge(hi_clk)); hi_cmd <= DUpdateWireOuts; 
		wait until (rising_edge(hi_clk));
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP; 
		wait until (rising_edge(hi_clk)); hi_drive <= '0'; 
		wait until (rising_edge(hi_clk)); wait until (rising_edge(hi_clk)); 
		for i in 0 to 31 loop
			wait until (rising_edge(hi_clk)); WireOuts(i) := hi_datain; 
		end loop;
		wait until (hi_busy = '0'); 
	end procedure UpdateWireOuts;

	-----------------------------------------------------------------------
	-- ActivateTriggerIn
	-----------------------------------------------------------------------
	procedure ActivateTriggerIn (
		ep  : in  std_logic_vector(7 downto 0);
		bit : in  integer) is 
		
		variable tmp_slv5 :     std_logic_vector(4 downto 0);
	begin
		tmp_slv5 := CONV_std_logic_vector(bit, 5);
		wait until (rising_edge(hi_clk)); hi_cmd <= DTriggers;
		wait until (rising_edge(hi_clk)); hi_cmd <= DActivateTriggerIn;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_dataout <= (x"000000" & ep);
		wait until (rising_edge(hi_clk)); hi_dataout <= SHL(x"00000001", tmp_slv5); 
		hi_cmd <= DNOP;
		wait until (rising_edge(hi_clk)); hi_dataout <= x"00000000";
		wait until (hi_busy = '0');
	end procedure ActivateTriggerIn;

	-----------------------------------------------------------------------
	-- UpdateTriggerOuts
	-----------------------------------------------------------------------
	procedure UpdateTriggerOuts is
	begin
		wait until (rising_edge(hi_clk)); hi_cmd <= DTriggers;
		wait until (rising_edge(hi_clk)); hi_cmd <= DUpdateTriggerOuts;
		wait until (rising_edge(hi_clk));
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP;
		wait until (rising_edge(hi_clk)); hi_drive <= '0';
		wait until (rising_edge(hi_clk)); wait until (rising_edge(hi_clk));
		wait until (rising_edge(hi_clk));
		
		for i in 0 to (UPDATE_TO_READOUT_CLOCKS-1) loop
				wait until (rising_edge(hi_clk));  
		end loop;
		
		for i in 0 to 31 loop
			wait until (rising_edge(hi_clk)); Triggered(i) := hi_datain;
		end loop;
		wait until (hi_busy = '0');
	end procedure UpdateTriggerOuts;

	-----------------------------------------------------------------------
	-- WriteToPipeIn
	-----------------------------------------------------------------------
	procedure WriteToPipeIn (
		ep      : in  std_logic_vector(7 downto 0);
		length  : in  integer) is

		variable len, i, j, k, blockSize : integer;
		variable tmp_slv8                : std_logic_vector(7 downto 0);
		variable tmp_slv32               : std_logic_vector(31 downto 0);
	begin
		len := (length / 4); j := 0; k := 0; blockSize := 1024;
		tmp_slv8 := CONV_std_logic_vector(BlockDelayStates, 8);
		tmp_slv32 := CONV_std_logic_vector(len, 32);
		
		wait until (rising_edge(hi_clk)); hi_cmd <= DPipes;
		wait until (rising_edge(hi_clk)); hi_cmd <= DWriteToPipeIn;
		wait until (rising_edge(hi_clk)); 
		hi_drive <= '1';
		hi_dataout <= (x"0000" & tmp_slv8 & ep);
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP;
		hi_dataout <= tmp_slv32;
		for i in 0 to len - 1 loop
			wait until (rising_edge(hi_clk));
			hi_dataout(7 downto 0) <= pipeIn(i*4);
			hi_dataout(15 downto 8) <= pipeIn((i*4)+1);
			hi_dataout(23 downto 16) <= pipeIn((i*4)+2);
			hi_dataout(31 downto 24) <= pipeIn((i*4)+3);
			j := j + 4;
			if (j = blockSize) then
				for k in 0 to BlockDelayStates - 1 loop
					wait until (rising_edge(hi_clk));
				end loop;
				j := 0;
			end if;
		end loop;
		wait until (hi_busy = '0');
	end procedure WriteToPipeIn;

	-----------------------------------------------------------------------
	-- ReadFromPipeOut
	-----------------------------------------------------------------------
	procedure ReadFromPipeOut (
		ep     : in  std_logic_vector(7 downto 0);
		length : in  integer) is
		
		variable len, i, j, k, blockSize : integer;
		variable tmp_slv8                : std_logic_vector(7 downto 0);
		variable tmp_slv32               : std_logic_vector(31 downto 0);
	begin
		len := (length / 4); j := 0; blockSize := 1024;
		tmp_slv8 := CONV_std_logic_vector(BlockDelayStates, 8);
		tmp_slv32 := CONV_std_logic_vector(len, 32);
		
		wait until (rising_edge(hi_clk)); hi_cmd <= DPipes;
		wait until (rising_edge(hi_clk)); hi_cmd <= DReadFromPipeOut;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_dataout <= (x"0000" & tmp_slv8 & ep);
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP;
		hi_dataout <= tmp_slv32;
		wait until (rising_edge(hi_clk));
		hi_drive <= '0';
		for i in 0 to len - 1 loop
			wait until (rising_edge(hi_clk));
			pipeOut(i*4) := hi_datain(7 downto 0);
			pipeOut((i*4)+1) := hi_datain(15 downto 8);
			pipeOut((i*4)+2) := hi_datain(23 downto 16);
			pipeOut((i*4)+3) := hi_datain(31 downto 24);
			j := j + 4;
			if (j = blockSize) then
				for k in 0 to BlockDelayStates - 1 loop
					wait until (rising_edge(hi_clk));
				end loop;
				j := 0;
			end if;
		end loop;
		wait until (hi_busy = '0');
	end procedure ReadFromPipeOut;

	-----------------------------------------------------------------------
	-- WriteToBlockPipeIn
	-----------------------------------------------------------------------
	procedure WriteToBlockPipeIn (
		ep          : in std_logic_vector(7 downto 0);
		blockLength : in integer;
		length      : in integer) is
		
		variable len, i, j, k, blockSize, blockNum : integer;
		variable tmp_slv8                          : std_logic_vector(7 downto 0);
		variable tmp_slv16                         : std_logic_vector(15 downto 0);
		variable tmp_slv32                         : std_logic_vector(31 downto 0);
	begin
		len := (length/4); blockSize := (blockLength/4); j := 0; k := 0;
		blockNum := (len/blockSize);
		tmp_slv8 := CONV_std_logic_vector(BlockDelayStates, 8);
		tmp_slv16 := CONV_std_logic_vector(blockSize, 16);
		tmp_slv32 := CONV_std_logic_vector(len, 32);
		
		wait until (rising_edge(hi_clk)); hi_cmd <= DPipes;
		wait until (rising_edge(hi_clk)); hi_cmd <= DWriteToBlockPipeIn;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_dataout <= (x"0000" & tmp_slv8 & ep);
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP;
		hi_dataout <= tmp_slv32;
		wait until (rising_edge(hi_clk)); hi_dataout <= x"0000" & tmp_slv16;
		wait until (rising_edge(hi_clk));
		tmp_slv16 := (CONV_std_logic_vector(PostReadyDelay, 8) & CONV_std_logic_vector(ReadyCheckDelay, 8));
		hi_dataout <= x"0000" & tmp_slv16;
		for i in 1 to blockNum loop
			while (hi_busy = '1') loop wait until (rising_edge(hi_clk)); end loop;
			while (hi_busy = '0') loop wait until (rising_edge(hi_clk)); end loop;
			wait until (rising_edge(hi_clk)); wait until (rising_edge(hi_clk));
			for j in 1 to blockSize loop
				hi_dataout(7 downto 0) <= pipeIn(k);
				hi_dataout(15 downto 8) <= pipeIn(k+1);
				hi_dataout(23 downto 16) <= pipeIn(k+2);
				hi_dataout(31 downto 24) <= pipeIn(k+3);
				wait until (rising_edge(hi_clk)); k:=k+4;
			end loop;
			for j in 1 to BlockDelayStates loop 
				wait until (rising_edge(hi_clk)); 
			end loop;
		end loop;
		wait until (hi_busy = '0');
	end procedure WriteToBlockPipeIn;

	-----------------------------------------------------------------------
	-- ReadFromBlockPipeOut
	-----------------------------------------------------------------------
	procedure ReadFromBlockPipeOut (
		ep          : in std_logic_vector(7 downto 0);
		blockLength : in integer;
		length      : in integer) is
		
		variable len, i, j, k, blockSize, blockNum : integer;
		variable tmp_slv8                          : std_logic_vector(7 downto 0);
		variable tmp_slv16                         : std_logic_vector(15 downto 0);
		variable tmp_slv32                         : std_logic_vector(31 downto 0);
	begin
		len := (length/4); blockSize := (blockLength/4); j := 0; k := 0;
		blockNum := (len/blockSize);
		tmp_slv8 := CONV_std_logic_vector(BlockDelayStates, 8);
		tmp_slv16 := CONV_std_logic_vector(blockSize, 16);
		tmp_slv32 := CONV_std_logic_vector(len, 32);
		
		wait until (rising_edge(hi_clk)); hi_cmd <= DPipes;
		wait until (rising_edge(hi_clk)); hi_cmd <= DReadFromBlockPipeOut;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_dataout <= (x"0000" & tmp_slv8 & ep);
		wait until (rising_edge(hi_clk)); hi_cmd <= DNOP;
		hi_dataout <= tmp_slv32;
		wait until (rising_edge(hi_clk)); hi_dataout <= x"0000" & tmp_slv16;
		wait until (rising_edge(hi_clk));
		tmp_slv16 := (CONV_std_logic_vector(PostReadyDelay, 8) & CONV_std_logic_vector(ReadyCheckDelay, 8));
		hi_dataout <= x"0000" & tmp_slv16;
		wait until (rising_edge(hi_clk)); hi_drive <= '0';
		for i in 1 to blockNum loop
			while (hi_busy = '1') loop wait until (rising_edge(hi_clk)); end loop;
			while (hi_busy = '0') loop wait until (rising_edge(hi_clk)); end loop;
			wait until (rising_edge(hi_clk)); wait until (rising_edge(hi_clk));
			for j in 1 to blockSize loop
				pipeOut(k) := hi_datain(7 downto 0); 
				pipeOut(k+1) := hi_datain(15 downto 8);
				pipeOut(k+2) := hi_datain(23 downto 16);
				pipeOut(k+3) := hi_datain(31 downto 24);
				wait until (rising_edge(hi_clk)); k:=k+4;
			end loop;
			for j in 1 to BlockDelayStates loop wait until (rising_edge(hi_clk)); end loop;
		end loop;
		wait until (hi_busy = '0');
	end procedure ReadFromBlockPipeOut;
	
	-----------------------------------------------------------------------
	-- WriteRegister
	-----------------------------------------------------------------------
	procedure WriteRegister (
		address  : in  std_logic_vector(31 downto 0);
		data     : in  std_logic_vector(31 downto 0)) is
	begin
		wait until (rising_edge(hi_clk)); hi_cmd <= DRegisters;
		wait until (rising_edge(hi_clk)); hi_cmd <= DWriteRegister;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_cmd <= DNOP;
		wait until (rising_edge(hi_clk)); hi_dataout <= address; 
		wait until (rising_edge(hi_clk)); hi_dataout <= data;
		wait until (hi_busy = '0'); hi_drive <= '0';  
	end procedure WriteRegister;
	
	-----------------------------------------------------------------------
	-- ReadRegister
	-----------------------------------------------------------------------
	procedure ReadRegister (
		address  : in  std_logic_vector(31 downto 0);
		data     : out std_logic_vector(31 downto 0)) is
	begin
		wait until (rising_edge(hi_clk)); hi_cmd <= DRegisters;
		wait until (rising_edge(hi_clk)); hi_cmd <= DReadRegister;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_cmd <= DNOP;
		wait until (rising_edge(hi_clk)); hi_dataout <= address; 
		wait until (rising_edge(hi_clk)); hi_drive <= '0';
		wait until (rising_edge(hi_clk));
		wait until (rising_edge(hi_clk)); data := hi_datain;
		wait until (hi_busy = '0');
	end procedure ReadRegister;
	
	
	-----------------------------------------------------------------------
	-- WriteRegisterSet
	-----------------------------------------------------------------------
	procedure WriteRegisterSet is
		variable i             :     integer;
		variable u32Count_int  :     integer;
	begin
	  u32Count_int := CONV_INTEGER(u32Count);
		wait until (rising_edge(hi_clk)); hi_cmd <= DRegisters;
		wait until (rising_edge(hi_clk)); hi_cmd <= DWriteRegisterSet;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_cmd <= DNOP;
		wait until (rising_edge(hi_clk)); hi_dataout <= u32Count; 
		for i in 1 to u32Count_int loop
			wait until (rising_edge(hi_clk)); hi_dataout <= u32Address(i-1);
			wait until (rising_edge(hi_clk)); hi_dataout <= u32Data(i-1);
			wait until (rising_edge(hi_clk)); wait until (rising_edge(hi_clk));
		end loop;
		wait until (hi_busy = '0'); hi_drive <= '0';  
	end procedure WriteRegisterSet;
	
	-----------------------------------------------------------------------
	-- ReadRegisterSet
	-----------------------------------------------------------------------
	procedure ReadRegisterSet is
		variable i             :     integer;
		variable u32Count_int  :     integer;
	begin
	  u32Count_int := CONV_INTEGER(u32Count);
		wait until (rising_edge(hi_clk)); hi_cmd <= DRegisters;
		wait until (rising_edge(hi_clk)); hi_cmd <= DReadRegisterSet;
		wait until (rising_edge(hi_clk));
		hi_drive <= '1';
		hi_cmd <= DNOP;
		wait until (rising_edge(hi_clk)); hi_dataout <= u32Count; 
		for i in 1 to u32Count_int loop
			wait until (rising_edge(hi_clk)); hi_dataout <= u32Address(i-1);
			wait until (rising_edge(hi_clk)); hi_drive <= '0'; 
			wait until (rising_edge(hi_clk)); 
			wait until (rising_edge(hi_clk)); u32Data(i-1) := hi_datain;
			hi_drive <= '1';
		end loop;
		wait until (hi_busy = '0');
	end procedure ReadRegisterSet;
	
	-----------------------------------------------------------------------
	-- Available User Task and Function Calls:
	--    FrontPanelReset;              -- Always start routine with FrontPanelReset;
	--    SetWireInValue(ep, val, mask);
	--    UpdateWireIns;
	--    UpdateWireOuts;
	--    GetWireOutValue(ep);          -- returns a 16 bit SLV
	--    ActivateTriggerIn(ep, bit);   -- bit is an integer 0-15
	--    UpdateTriggerOuts;
	--    IsTriggered(ep, mask);        -- returns a BOOLEAN
	--    WriteToPipeIn(ep, length);    -- pass pipeIn array data; length is integer
	--    ReadFromPipeOut(ep, length);  -- pass data to pipeOut array; length is integer
	--    WriteToBlockPipeIn(ep, blockSize, length);   -- pass pipeIn array data; blockSize and length are integers
	--    ReadFromBlockPipeOut(ep, blockSize, length); -- pass data to pipeOut array; blockSize and length are integers
	--    WriteRegister(addr, data);  
	--    ReadRegister(addr, data);
	--    WriteRegisterSet();  
	--    ReadRegisterSet();
	--
	-- *  Pipes operate by passing arrays of data back and forth to the user's
	--    design.  If you need multiple arrays, you can create a new procedure
	--    above and connect it to a differnet array.  More information is
	--    available in Opal Kelly documentation and online support tutorial.
	-----------------------------------------------------------------------
	--<<<<<<<<<<<<<<<<<<< OKHOSTCALLS END PASTE HERE >>>>>>>>>>>>>>>>>>>>>>-- 
	
		variable msg_line           : line;     -- type defined in textio.vhd
		variable k                  : integer;
		variable r1, r2, exp, sum  : std_logic_vector(31 downto 0) := x"0000_0000";
		
		begin
			FrontPanelReset;                      -- Start routine with FrontPanelReset;
			
			r1 := x"0123_4567";
			r2 := x"0000_0000";
		wait for 1 ns;
			--------------------------------------------------------------------
			-- Sample procedure and function operations
			--    We'll generate changing numbers, send them to the DUT using
			--    simulated FrontPanel API calls and pull out the result of the 
			--    DUT 'add' function.  We will also automate the verification 
			--    process.
			--------------------------------------------------------------------
			for k in 0 to 3 loop
				-- Set the two ADDER inputs to changing 16-bit values.
				r1 := r1 + x"1111_1111";
				r2 := r2 + x"2222_2222";
				wait for 1 ns;
				exp := r1 + r2;
				SetWireInValue(x"01", r1, x"ffff_ffff");   -- FRONTPANEL API
				SetWireInValue(x"02", r2, x"ffff_ffff");   -- FRONTPANEL API
				UpdateWireIns;                        -- FRONTPANEL API
	
				-- The ADDER result will be ready.  UpdateWireOuts to get it.
				UpdateWireOuts;                   -- FRONTPANEL API
				sum := GetWireOutValue(x"21");    -- FRONTPANEL API
				if (exp = sum) then
					write(msg_line, STRING'("SUCCESS -- Expected: 0x"));
					hwrite(msg_line, exp);
					write(msg_line, STRING'("   Received: 0x"));
					hwrite(msg_line, sum);
					write(msg_line, STRING'(" at time "));
					write(msg_line, now);
					
					writeline(output, msg_line);
				else
					write(msg_line, STRING'("FAILURE -- Expected: 0x"));
					hwrite(msg_line, exp);
					write(msg_line, STRING'("   Received: 0x"));
					hwrite(msg_line, sum);
					write(msg_line, STRING'(" at time "));
					write(msg_line, now);
					
					writeline(output, msg_line);
				end if;
			end loop;
			
			wait;
	end process;

end sim;
