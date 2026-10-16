library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity memory_test is
  port (
    sys_clk         : in  std_logic;
    sys_resetn      : in  std_logic;
    button          : in  std_logic;
    led             : out std_logic_vector(5 downto 0);
    uart_txp        : out std_logic;
    O_psram_ck      : out std_logic_vector(1 downto 0);
    O_psram_ck_n    : out std_logic_vector(1 downto 0);
    IO_psram_rwds   : inout std_logic_vector(1 downto 0);
    IO_psram_dq     : inout std_logic_vector(15 downto 0);
    O_psram_reset_n : out std_logic_vector(1 downto 0);
    O_psram_cs_n    : out std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of memory_test is
  constant BYTES   : unsigned(21 downto 0) := to_unsigned(1024*1024, 22);
  constant FREQ    : integer := 81000000;
  constant LATENCY : integer := 3;
  constant NO_PAUSE : std_logic := '0';

  constant TEST_ZERO              : unsigned(3 downto 0) := to_unsigned(0, 4);
  constant TEST_INIT              : unsigned(3 downto 0) := to_unsigned(1, 4);
  constant TEST_WRITE             : unsigned(3 downto 0) := to_unsigned(2, 4);
  constant TEST_READ              : unsigned(3 downto 0) := to_unsigned(3, 4);
  constant TEST_DONE              : unsigned(3 downto 0) := to_unsigned(4, 4);
  constant TEST_FAIL_INIT_TIMEOUT : unsigned(3 downto 0) := to_unsigned(5, 4);
  constant TEST_FAIL_WRITE_TIMEOUT: unsigned(3 downto 0) := to_unsigned(6, 4);
  constant TEST_FAIL_READ_TIMEOUT : unsigned(3 downto 0) := to_unsigned(7, 4);
  constant TEST_FAIL_READ_WRONG   : unsigned(3 downto 0) := to_unsigned(8, 4);
  constant PAUSE                  : unsigned(3 downto 0) := to_unsigned(9, 4);

  signal clk, clk_p : std_logic;

  signal read_s, write_s, byte_write_s : std_logic := '0';
  signal address : unsigned(21 downto 0) := (others => '0');
  signal din, dout : std_logic_vector(15 downto 0) := (others => '0');
  signal busy : std_logic;

  signal state, new_state : unsigned(3 downto 0) := TEST_ZERO;
  signal cycle : unsigned(4 downto 0) := (others => '0');
  signal write_1x, write_2x, read_1x, read_2x : unsigned(23 downto 0) := (others => '0');
  signal tick : std_logic := '0';
  signal ticks : unsigned(3 downto 0) := (others => '0');
  signal error_s : std_logic := '0';
  signal dout_parity : std_logic;

  signal new_addr_0, new_addr_1 : unsigned(8 downto 0) := (others => '0');
  signal new_addr : unsigned(21 downto 0) := (others => '0');

  signal tick_counter : unsigned(23 downto 0) := (others => '0');

  signal state_p : unsigned(3 downto 0) := (others => '0');
  signal print_counters, print_counters_p : unsigned(3 downto 0) := (others => '0');
  signal total_write, total_read : unsigned(23 downto 0);

  signal pr_start  : std_logic := '0';
  signal pr_is_hex : std_logic := '0';
  signal pr_data   : std_logic_vector(1023 downto 0) := (others => '0');
  signal pr_hex_bytes : unsigned(7 downto 0) := to_unsigned(3, 8);
  signal pr_idle : std_logic;

  function hash(a : unsigned(21 downto 0)) return std_logic_vector is
    variable v : std_logic_vector(7 downto 0);
  begin
    v := std_logic_vector(a(7 downto 0) xor a(15 downto 8) xor resize(a(21 downto 16), 8) xor to_unsigned(16#C3#, 8));
    return v;
  end function;

  function pack_string(s : string) return std_logic_vector is
    variable outv : std_logic_vector(1023 downto 0) := (others => '0');
    variable idx  : integer;
  begin
    for i in s'range loop
      idx := i - s'low;
      if idx <= 127 then
        outv(1023 - idx*8 downto 1016 - idx*8) := std_logic_vector(to_unsigned(character'pos(s(i)), 8));
      end if;
    end loop;
    return outv;
  end function;

  function pack_line(s : string) return std_logic_vector is
    variable outv : std_logic_vector(1023 downto 0) := (others => '0');
    variable idx  : integer;
  begin
    outv := pack_string(s);
    idx := s'length;
    if idx <= 127 then
      outv(1023 - idx*8 downto 1016 - idx*8) := x"0A";
    end if;
    return outv;
  end function;

  function pack_hex24(v : unsigned(23 downto 0)) return std_logic_vector is
    variable outv : std_logic_vector(1023 downto 0) := (others => '0');
  begin
    outv(1023 downto 1000) := std_logic_vector(v);
    return outv;
  end function;

begin
  O_psram_reset_n <= (others => sys_resetn);
  O_psram_ck_n <= (others => '0');

  total_write <= write_1x + write_2x;
  total_read <= read_1x + read_2x;

  dout_parity <= dout(7) and dout(6) and dout(5) and dout(4) and dout(3) and dout(2) and dout(1) and dout(0);
  led <= not (error_s & dout_parity & dout(3 downto 0));

  u_pll : entity work.gowin_rpll
    port map (
      clkout  => clk,
      clkoutp => clk_p,
      clkin   => sys_clk
    );

  u_mem : entity work.psram_controller
    generic map (
      FREQ => FREQ,
      LATENCY => LATENCY
    )
    port map (
      clk => clk,
      clk_p => clk_p,
      resetn => sys_resetn,
      read => read_s,
      write => write_s,
      addr => std_logic_vector(address),
      din => din,
      byte_write => byte_write_s,
      dout => dout,
      busy => busy,
      O_psram_ck => O_psram_ck,
      IO_psram_rwds => IO_psram_rwds,
      IO_psram_dq => IO_psram_dq,
      O_psram_cs_n => O_psram_cs_n
    );

  u_print : entity work.print_uart
    generic map (
      clk_freq => FREQ,
      uart_freq => 115200
    )
    port map (
      clk => clk,
      start => pr_start,
      is_hex => pr_is_hex,
      data_in => pr_data,
      hex_bytes => pr_hex_bytes,
      idle => pr_idle,
      tx_p => uart_txp
    );

  process(clk)
    variable high_part : unsigned(5 downto 0);
  begin
    if rising_edge(clk) then
      if sys_resetn = '0' then
        new_addr_0 <= (others => '0');
        new_addr_1 <= (others => '0');
        new_addr <= (others => '0');
      else
        new_addr_0 <= ('0' & address(7 downto 0)) + 1;
        new_addr_1 <= ('0' & address(15 downto 8)) + new_addr_0(8);
        high_part := address(21 downto 16);
        if new_addr_1(8) = '1' then
          high_part := high_part + 1;
        end if;
        new_addr <= high_part & new_addr_1(7 downto 0) & new_addr_0(7 downto 0);
      end if;
    end if;
  end process;

  process(clk)
    variable expected_hash : std_logic_vector(7 downto 0);
    variable dout_byte : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clk) then
      read_s <= '0';
      write_s <= '0';
      byte_write_s <= '1';

      if tick = '1' and (state = TEST_INIT or state = PAUSE) then
        ticks <= ticks + 1;
      end if;

      if sys_resetn = '0' or state = TEST_ZERO then
        cycle <= (others => '0');
        ticks <= (others => '0');
        new_state <= TEST_INIT;
        state <= PAUSE;
        error_s <= '0';
        address <= (others => '0');
        write_1x <= (others => '0');
        write_2x <= (others => '0');
        read_1x <= (others => '0');
        read_2x <= (others => '0');

      elsif state = TEST_INIT then
        if busy = '0' then
          new_state <= TEST_WRITE;
          state <= PAUSE;
        elsif ticks = to_unsigned(5, 4) then
          new_state <= TEST_FAIL_INIT_TIMEOUT;
          error_s <= '1';
          state <= PAUSE;
        end if;

      elsif state = TEST_WRITE then
        cycle <= cycle + 1;
        if cycle = 0 then
          write_s <= '1';
          din <= hash(address) & hash(address);
        elsif write_s = '0' and busy = '0' then
          cycle <= (others => '0');
          if cycle > to_unsigned(4 + LATENCY, 5) then
            write_2x <= write_2x + 1;
          else
            write_1x <= write_1x + 1;
          end if;

          if address = BYTES - 1 then
            new_state <= TEST_READ;
            state <= PAUSE;
          else
            address <= new_addr;
          end if;
        elsif cycle = to_unsigned(5 + LATENCY*2, 5) then
          new_state <= TEST_FAIL_WRITE_TIMEOUT;
          error_s <= '1';
          state <= PAUSE;
        end if;

      elsif state = TEST_READ then
        cycle <= cycle + 1;
        if cycle = 0 then
          read_s <= '1';
        elsif read_s = '0' and busy = '0' then
          cycle <= (others => '0');
          if cycle > to_unsigned(10 + LATENCY, 5) then
            read_2x <= read_2x + 1;
          else
            read_1x <= read_1x + 1;
          end if;

          expected_hash := hash(address);
          if address(0) = '1' then
            dout_byte := dout(15 downto 8);
          else
            dout_byte := dout(7 downto 0);
          end if;

          if dout_byte /= expected_hash then
            new_state <= TEST_FAIL_READ_WRONG;
            error_s <= '1';
            state <= PAUSE;
          elsif address = BYTES - 1 then
            new_state <= TEST_DONE;
            state <= PAUSE;
          else
            address <= new_addr;
          end if;

        elsif cycle = to_unsigned(10 + LATENCY*2, 5) then
          new_state <= TEST_FAIL_READ_TIMEOUT;
          error_s <= '1';
          state <= PAUSE;
        end if;

      elsif state = PAUSE then
        address <= (others => '0');
        if ticks = to_unsigned(2, 4) or NO_PAUSE = '1' then
          ticks <= (others => '0');
          state <= new_state;
        end if;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if sys_resetn = '0' then
        tick_counter <= to_unsigned(FREQ/10, tick_counter'length);
      elsif tick_counter = 0 then
        tick_counter <= to_unsigned(FREQ/10, tick_counter'length);
      else
        tick_counter <= tick_counter - 1;
      end if;

      if tick_counter = 0 then
        tick <= '1';
      else
        tick <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      pr_start <= '0';
      state_p <= state;
      print_counters_p <= print_counters;

      if state /= state_p and pr_idle = '1' then
        pr_is_hex <= '0';
        if state = TEST_INIT then pr_data <= pack_line("Initializing HyperRAM test..."); pr_start <= '1'; end if;
        if state = TEST_WRITE then pr_data <= pack_line("Writing..."); pr_start <= '1'; end if;
        if state = TEST_READ then pr_data <= pack_line("Reading..."); pr_start <= '1'; end if;
        if state = TEST_DONE then pr_data <= pack_line("All done successfully."); pr_start <= '1'; end if;
        if state = TEST_FAIL_INIT_TIMEOUT then pr_data <= pack_line("FAIL. Initialization timeout."); pr_start <= '1'; end if;
        if state = TEST_FAIL_WRITE_TIMEOUT then pr_data <= pack_line("FAIL. Write time out."); pr_start <= '1'; end if;
        if state = TEST_FAIL_READ_TIMEOUT then pr_data <= pack_line("FAIL. Read time out."); pr_start <= '1'; end if;
        if state = TEST_FAIL_READ_WRONG then pr_data <= pack_line("FAIL. Read wrong data."); pr_start <= '1'; end if;

        if state = TEST_DONE or state = TEST_FAIL_INIT_TIMEOUT or state = TEST_FAIL_READ_TIMEOUT or state = TEST_FAIL_READ_WRONG or state = TEST_FAIL_WRITE_TIMEOUT then
          print_counters <= to_unsigned(1, 4);
        end if;
      end if;

      if print_counters > 0 and print_counters = print_counters_p and pr_idle = '1' then
        case to_integer(print_counters) is
          when 1  => pr_is_hex <= '0'; pr_data <= pack_string("Latency counters: write_1x="); pr_start <= '1';
          when 2  => pr_is_hex <= '1'; pr_data <= pack_hex24(write_1x); pr_start <= '1';
          when 3  => pr_is_hex <= '0'; pr_data <= pack_string(", write_2x="); pr_start <= '1';
          when 4  => pr_is_hex <= '1'; pr_data <= pack_hex24(write_2x); pr_start <= '1';
          when 5  => pr_is_hex <= '0'; pr_data <= pack_string(", read_1x="); pr_start <= '1';
          when 6  => pr_is_hex <= '1'; pr_data <= pack_hex24(read_1x); pr_start <= '1';
          when 7  => pr_is_hex <= '0'; pr_data <= pack_string(", read_2x="); pr_start <= '1';
          when 8  => pr_is_hex <= '1'; pr_data <= pack_hex24(read_2x); pr_start <= '1';
          when 9  => pr_is_hex <= '0'; pr_data <= pack_string(", total_w="); pr_start <= '1';
          when 10 => pr_is_hex <= '1'; pr_data <= pack_hex24(total_write); pr_start <= '1';
          when 11 => pr_is_hex <= '0'; pr_data <= pack_string(", total_r="); pr_start <= '1';
          when 12 => pr_is_hex <= '1'; pr_data <= pack_hex24(total_read); pr_start <= '1';
          when 13 => pr_is_hex <= '0'; pr_data <= pack_line(""); pr_start <= '1';
          when others => null;
        end case;

        if print_counters = to_unsigned(13, 4) then
          print_counters <= (others => '0');
        else
          print_counters <= print_counters + 1;
        end if;
      end if;
    end if;
  end process;

end architecture;
