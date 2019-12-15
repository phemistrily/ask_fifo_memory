
--SPECIFICATION
-- #INPUT#
-- 1 push button clock using to run actions
-- 1 read flag switcher
-- 1 write flag switcher

-- #OUTPUT#
-- 1 BCD FLAG: If read then I. If write then O. If both then E
-- 1 BCD CHECKMEM: If memory is empty then E. If memory is full then F
-- 3 BCD LED: display numbers 0-9



Library IEEE;
USE IEEE.Std_logic_1164.all;
USE IEEE.NUMERIC_STD.ALL;

entity fifo_memory is
	generic (
		memory_architecture: natural := 16 --architecutre of memory (16 bit default)
	);
	port (
		data_in: in std_logic_vector(memory_architecture-1 downto 0); -- data input. Value which will be put into our memory
		read_flag: in std_logic; -- read flag
		write_flag: in std_logic; -- write flag
		clk: in std_logic; -- not sure to use
		-- action_button: in std_logic; -- master button
		-- data_out: buffer std_logic_vector(memory_architecture-1 downto 0); -- data output. Value which will be throw by our memory. This one will be converted to our 7-seg display
		f_led_out: out std_logic_vector(6 downto 0);
		cm_led_out : out std_logic_vector(6 downto 0);
		d_led_out0 : out std_logic_vector(6 downto 0);
		d_led_out1 : out std_logic_vector(6 downto 0);
		d_led_out2 : out std_logic_vector(6 downto 0)
		-- d_led_out3 : out std_logic_vector(6 downto 0)
	);
end fifo_memory;

architecture Behavioral of fifo_memory is

	signal write_counter : unsigned (memory_architecture-1 downto 0) := (others => '0'); --UUUUUUUUUUUU1101
	signal read_counter : unsigned (memory_architecture-1 downto 0) := (others => '0');
	type array_memory is array(0 to (2**4)-1) of unsigned(memory_architecture-1 downto 0);
	signal memory : array_memory;
	signal full_memory  : std_logic;
	signal empty_memory : std_logic;
	signal data_out: std_logic_vector(memory_architecture-1 downto 0);
	signal d_value :  integer;
	signal d_units : std_logic_vector (memory_architecture-1 downto 0);
	signal d_tens : std_logic_vector (memory_architecture-1 downto 0);
	signal d_hundreds : std_logic_vector (memory_architecture-1 downto 0);
	-- signal d_thousands : std_logic_vector (memory_architecture-1 downto 0);
	signal d_start_bcd : std_logic;
	signal pos0, pos1, pos2, pos3 : natural range 0 to 9; -- std_logic_vector(3 downto 0);
	
	function zero_nine_BCD
	(
		d_value_in : in std_logic_vector(memory_architecture-1 downto 0)
	)
		return std_logic_vector is 
		variable returned_value : std_logic_vector (6 downto 0);
			begin
			case  d_value_in(3 downto 0) is
				when "0000"=> returned_value :="0000001";  -- '0'
				when "0001"=> returned_value :="1001111";  -- '1'
				when "0010"=> returned_value :="0010010";  -- '2'
				when "0011"=> returned_value :="0000110";  -- '3'
				when "0100"=> returned_value :="1001100";  -- '4' 
				when "0101"=> returned_value :="0100100";  -- '5'
				when "0110"=> returned_value :="0100000";  -- '6'
				when "0111"=> returned_value :="0001111";  -- '7'
				when "1000"=> returned_value :="0000000";  -- '8'
				when "1001"=> returned_value :="0000100";  -- '9'
				when others=> returned_value :="1111111"; 
			end case;
			return std_logic_vector(returned_value);
		end function zero_nine_BCD;

	component bcd_flag is
	port (
		f_led_out: out std_logic_vector(6 downto 0)
	);

	end component bcd_flag;
	begin
	
	
	action: process(clk) -- create process on clk change
		begin
		if rising_edge(clk) then -- if clk'event and clk='1' then
			if (read_flag='1' and full_memory='0' and write_flag='0') then-- check if read_flag = 1
				memory(to_integer(write_counter)) <= unsigned(data_in);
				write_counter <= write_counter + 1;
			end if;
			if (write_flag='1' and empty_memory='0' and read_flag='0') then-- check if write_flag = 1
				data_out <= std_logic_vector(memory(to_integer(read_counter)));
				read_counter <= read_counter + 1;
			end if;
		end if;
	end process action;
	full_memory  <= '1' when read_counter = write_counter+1 else '0';
	empty_memory <= '1' when read_counter = write_counter   else '0';
	
	flagBCD: process(read_flag, write_flag)
		begin
		if (read_flag='1' and write_flag='0') then
			f_led_out <= "1001111"; -- I
		end if;
		if (read_flag='0' and write_flag='1') then
			f_led_out <= "0000001"; -- O
		end if;
		if (read_flag='1' and write_flag='1') then
			f_led_out <= "0110000"; -- E
		end if;
	end process flagBCD;
	
	checkMEM: process(full_memory,empty_memory)
		begin
		if (full_memory='0' and empty_memory='0') then
			cm_led_out <= "1001111"; -- O
		end if;
		if (full_memory='1') then
			cm_led_out <= "0111000"; -- F
		end if;
		if (empty_memory='1') then
			cm_led_out <= "0110000"; -- E
		end if;
	end process checkMEM;
	
	d_value <= to_integer(signed(data_out(6 downto 0)));
	--prepareOutputBCD: process(data_out)
	--	variable d_value_int : integer;
	--	begin
		--if write_flag='1' then
	--		d_value_int := to_integer(unsigned(data_out));
	--		d_value <= d_value_int;
		--end if;
	--end process prepareOutputBCD;
	
	assignDigitsBCD: process (d_value)
		begin
		d_units <= std_logic_vector(to_unsigned(d_value mod 10,d_units'LENGTH));
		d_tens <= std_logic_vector(to_unsigned(((d_value / 10) mod 10),d_tens'LENGTH));
		d_hundreds <= std_logic_vector(to_unsigned(((d_value / 100) mod 10),d_hundreds'LENGTH));
		-- d_thousands <= std_logic_vector(to_unsigned((d_value / 1000) mod 10,d_thousands'LENGTH));
		d_start_bcd <= '1';
	end process assignDigitsBCD;
	
	pushDigitsBCD: process (d_start_bcd)
			begin
			if d_start_bcd='1' then
				d_led_out0 <= zero_nine_BCD(std_logic_vector(d_units));
				d_led_out1 <= zero_nine_BCD(std_logic_vector(d_tens));
				d_led_out2 <= zero_nine_BCD(std_logic_vector(d_hundreds));
				--d_led_out3 <= zero_nine_BCD(std_logic_vector(d_thousands));
			end if;
		end process pushDigitsBCD;
--	bcdt: bcd_flag PORT MAP(
--		f_led_outs
--	);
end Behavioral;