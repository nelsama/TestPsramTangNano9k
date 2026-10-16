library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity print_uart is
  generic (
    clk_freq  : integer := 81000000;
    uart_freq : integer := 115200
  );
  port (
    clk        : in  std_logic;
    start      : in  std_logic;
    is_hex     : in  std_logic; -- '0': string, '1': hex
    data_in    : in  std_logic_vector(1023 downto 0);
    hex_bytes  : in  unsigned(7 downto 0); -- e.g. 3 -> 24-bit hex
    idle       : out std_logic;
    tx_p       : out std_logic
  );
end entity;

architecture rtl of print_uart is
  type state_t is (IDLE_ST, STR_ST, HEX_HI_ST, HEX_LO_ST);
  signal state : state_t := IDLE_ST;

  signal buffer_reg : std_logic_vector(1023 downto 0) := (others => '0');
  signal ptr        : integer range 0 to 127 := 127;
  signal limit_ptr  : integer range 0 to 127 := 0;
  signal pending_lf : std_logic := '0';

  signal tx_busy : std_logic;
  signal tx_wr   : std_logic := '0';
  signal tx_din  : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_inflight : std_logic := '0';

  function nibble_to_ascii(n : std_logic_vector(3 downto 0)) return std_logic_vector is
    variable v : unsigned(3 downto 0);
  begin
    v := unsigned(n);
    if v < 10 then
      return std_logic_vector(to_unsigned(16#30#, 8) + resize(v, 8));
    else
      return std_logic_vector(to_unsigned(16#61#, 8) + resize(v - 10, 8));
    end if;
  end function;

  function byte_at(buf : std_logic_vector(1023 downto 0); index : integer) return std_logic_vector is
    variable b : std_logic_vector(7 downto 0);
  begin
    b := buf(index*8 + 7 downto index*8);
    return b;
  end function;

begin
  u_tx : entity work.uart_tx_v2
    generic map (
      clk_freq => clk_freq,
      uart_freq => uart_freq
    )
    port map (
      clk => clk,
      din => tx_din,
      wr_en => tx_wr,
      tx_busy => tx_busy,
      tx_p => tx_p
    );

  process(clk)
    variable cur : std_logic_vector(7 downto 0);
    variable n   : std_logic_vector(3 downto 0);
  begin
    if rising_edge(clk) then
      tx_wr <= '0';

      if tx_inflight = '1' then
        if tx_busy = '1' then
          tx_inflight <= '0';
        end if;

      elsif state = IDLE_ST then
        if start = '1' then
          buffer_reg <= data_in;
          ptr <= 127;
          pending_lf <= '0';
          if is_hex = '1' then
            limit_ptr <= 128 - to_integer(hex_bytes);
            state <= HEX_HI_ST;
          else
            state <= STR_ST;
          end if;
        end if;

      elsif tx_busy = '0' then
        case state is
          when STR_ST =>
            if pending_lf = '1' then
              tx_din <= x"0A";
              tx_wr <= '1';
              tx_inflight <= '1';
              pending_lf <= '0';
              if ptr = 0 then
                state <= IDLE_ST;
              else
                ptr <= ptr - 1;
              end if;
            else
              cur := byte_at(buffer_reg, ptr);
              if cur = x"00" then
                state <= IDLE_ST;
              elsif cur = x"0A" then
                tx_din <= x"0D";
                tx_wr <= '1';
                tx_inflight <= '1';
                pending_lf <= '1';
              else
                tx_din <= cur;
                tx_wr <= '1';
                tx_inflight <= '1';
                if ptr = 0 then
                  state <= IDLE_ST;
                else
                  ptr <= ptr - 1;
                end if;
              end if;
            end if;

          when HEX_HI_ST =>
            n := byte_at(buffer_reg, ptr)(7 downto 4);
            tx_din <= nibble_to_ascii(n);
            tx_wr <= '1';
            tx_inflight <= '1';
            state <= HEX_LO_ST;

          when HEX_LO_ST =>
            n := byte_at(buffer_reg, ptr)(3 downto 0);
            tx_din <= nibble_to_ascii(n);
            tx_wr <= '1';
            tx_inflight <= '1';
            if ptr = limit_ptr then
              state <= IDLE_ST;
            else
              ptr <= ptr - 1;
              state <= HEX_HI_ST;
            end if;

          when others =>
            state <= IDLE_ST;
        end case;
      end if;
    end if;
  end process;

  idle <= '1' when state = IDLE_ST else '0';
end architecture;
