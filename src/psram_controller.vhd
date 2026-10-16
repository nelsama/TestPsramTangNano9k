library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity psram_controller is
  generic (
    FREQ    : integer := 81000000;
    LATENCY : integer := 3
  );
  port (
    clk         : in  std_logic;
    clk_p       : in  std_logic;
    resetn      : in  std_logic;
    read        : in  std_logic;
    write       : in  std_logic;
    addr        : in  std_logic_vector(21 downto 0);
    din         : in  std_logic_vector(15 downto 0);
    byte_write  : in  std_logic;
    dout        : out std_logic_vector(15 downto 0);
    busy        : out std_logic;
    O_psram_ck  : out std_logic_vector(1 downto 0);
    IO_psram_rwds : inout std_logic_vector(1 downto 0);
    IO_psram_dq : inout std_logic_vector(15 downto 0);
    O_psram_cs_n : out std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of psram_controller is
  type state_t is (INIT_ST, CONFIG_ST, IDLE_ST, READ_ST, WRITE_ST);
  signal state : state_t := INIT_ST;

  signal cfg_now, dq_oen, ram_cs_n, ck_e, ck_e_p : std_logic := '0';
  signal wait_for_rd_data : std_logic := '0';
  signal w_din : std_logic_vector(15 downto 0) := (others => '0');
  signal cycles_sr : std_logic_vector(23 downto 0) := (others => '0');
  signal dq_sr : std_logic_vector(63 downto 0) := (others => '0');

  signal dq_out_ris, dq_out_fal : std_logic_vector(7 downto 0);
  signal dq_in_ris, dq_in_fal : std_logic_vector(7 downto 0);
  signal rwds_out_ris, rwds_out_fal, rwds_oen : std_logic := '1';
  signal rwds_in_ris, rwds_in_fal : std_logic;
  signal additional_latency : std_logic := '0';

  signal rst_done, rst_done_p1 : std_logic := '0';
  constant INIT_TIME : integer := FREQ / 1000 * 160 / 1000;

  function clog2(n : integer) return integer is
    variable r : integer := 0;
    variable v : integer := n - 1;
  begin
    while v > 0 loop
      r := r + 1;
      v := v / 2;
    end loop;
    return r;
  end function;

  signal rst_cnt : unsigned(clog2(INIT_TIME + 1) downto 0) := (others => '0');

  signal cs_n_tbuf, rwds_tbuf, rwds_oen_tbuf, ck_tbuf : std_logic;
  signal dq_out_tbuf, dq_oen_tbuf : std_logic_vector(7 downto 0);

  component ODDR is
    port (
      CLK : in std_logic;
      D0  : in std_logic;
      D1  : in std_logic;
      TX  : in std_logic := '0';
      Q0  : out std_logic;
      Q1  : out std_logic
    );
  end component;

  component IDDR is
    port (
      CLK : in std_logic;
      D   : in std_logic;
      Q0  : out std_logic;
      Q1  : out std_logic
    );
  end component;

  function cr_latency_value(lat : integer) return std_logic_vector is
  begin
    case lat is
      when 3 => return "1110";
      when 4 => return "1111";
      when 5 => return "0000";
      when 6 => return "0001";
      when others => return "1110";
    end case;
  end function;

  constant CR_LATENCY : std_logic_vector(3 downto 0) := cr_latency_value(LATENCY);
  signal dout_reg : std_logic_vector(15 downto 0) := (others => '0');
begin
  dq_out_ris <= dq_sr(63 downto 56);
  dq_out_fal <= dq_sr(55 downto 48);

  busy <= '1' when state /= IDLE_ST else '0';
  dout <= dout_reg;

  process(clk)
  begin
    if rising_edge(clk) then
      cycles_sr <= cycles_sr(22 downto 0) & '0';
      dq_sr <= dq_sr(47 downto 0) & x"0000";
      ck_e_p <= ck_e;

      if state = INIT_ST and cfg_now = '1' then
        cycles_sr <= (others => '0');
        cycles_sr(0) <= '1';
        ram_cs_n <= '0';
        state <= CONFIG_ST;
      end if;

      if state = CONFIG_ST then
        if cycles_sr(0) = '1' then
          dq_sr <= x"6000010000008F" & CR_LATENCY & x"7";
          dq_oen <= '0';
          ck_e <= '1';
        end if;
        if cycles_sr(4) = '1' then
          state <= IDLE_ST;
          ck_e <= '0';
          cycles_sr <= (others => '0');
          cycles_sr(0) <= '1';
          dq_oen <= '1';
          ram_cs_n <= '1';
        end if;
      end if;

      if state = IDLE_ST then
        rwds_oen <= '1';
        ck_e <= '0';
        ram_cs_n <= '1';
        if read = '1' or write = '1' then
          dq_sr <= (not write) & "0100000000000" & addr(21 downto 4) & "0000000000000" & addr(3 downto 1) & "0000010011010100";
          ram_cs_n <= '0';
          ck_e <= '1';
          dq_oen <= '0';
          wait_for_rd_data <= '0';
          w_din <= din;
          cycles_sr <= (others => '0');
          cycles_sr(1) <= '1';
          if write = '1' then
            state <= WRITE_ST;
          else
            state <= READ_ST;
          end if;
        end if;
      end if;

      if state = READ_ST then
        if cycles_sr(3) = '1' then
          dq_oen <= '1';
        end if;
        if cycles_sr(9) = '1' then
          wait_for_rd_data <= '1';
        end if;
        if wait_for_rd_data = '1' and (rwds_in_ris xor rwds_in_fal) = '1' then
          dout_reg <= dq_in_ris & dq_in_fal;
          ram_cs_n <= '1';
          ck_e <= '0';
          state <= IDLE_ST;
        end if;
      end if;

      if state = WRITE_ST then
        if cycles_sr(5) = '1' then
          additional_latency <= rwds_in_fal;
        end if;

        if ((cycles_sr(2 + LATENCY) = '1') and ((LATENCY = 3 and rwds_in_fal = '0') or (LATENCY /= 3 and additional_latency = '0'))) or
           (cycles_sr(2 + LATENCY * 2) = '1') then
          rwds_oen <= '0';
          if byte_write = '1' then
            rwds_out_ris <= not addr(0);
            rwds_out_fal <= addr(0);
          else
            rwds_out_ris <= '0';
            rwds_out_fal <= '0';
          end if;
          dq_sr(63 downto 48) <= w_din;
          state <= IDLE_ST;
        end if;
      end if;

      if resetn = '0' then
        state <= INIT_ST;
        ram_cs_n <= '1';
        ck_e <= '0';
        dq_oen <= '1';
        rwds_oen <= '1';
        rwds_out_ris <= '0';
        rwds_out_fal <= '0';
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      rst_done_p1 <= rst_done;
      cfg_now <= rst_done and (not rst_done_p1);

      if to_integer(rst_cnt) /= INIT_TIME then
        rst_cnt <= rst_cnt + 1;
        rst_done <= '0';
      else
        rst_done <= '1';
      end if;

      if resetn = '0' then
        rst_cnt <= (others => '0');
        rst_done <= '0';
      end if;
    end if;
  end process;

  oddr_cs_n : ODDR
    port map (
      CLK => clk,
      D0  => ram_cs_n,
      D1  => ram_cs_n,
      Q0  => cs_n_tbuf,
      Q1  => open
    );

  oddr_rwds : ODDR
    port map (
      CLK => clk,
      D0  => rwds_out_ris,
      D1  => rwds_out_fal,
      TX  => rwds_oen,
      Q0  => rwds_tbuf,
      Q1  => rwds_oen_tbuf
    );

  gen_oddr_dq : for i in 0 to 7 generate
    oddr_dq_i : ODDR
      port map (
        CLK => clk,
        D0  => dq_out_ris(i),
        D1  => dq_out_fal(i),
        TX  => dq_oen,
        Q0  => dq_out_tbuf(i),
        Q1  => dq_oen_tbuf(i)
      );
  end generate;

  oddr_ck : ODDR
    port map (
      CLK => clk_p,
      D0  => ck_e_p,
      D1  => '0',
      Q0  => ck_tbuf,
      Q1  => open
    );

  iddr_rwds : IDDR
    port map (
      CLK => clk,
      D   => IO_psram_rwds(0),
      Q0  => rwds_in_ris,
      Q1  => rwds_in_fal
    );

  gen_iddr_dq : for i in 0 to 7 generate
    iddr_dq_i : IDDR
      port map (
        CLK => clk,
        D   => IO_psram_dq(i),
        Q0  => dq_in_ris(i),
        Q1  => dq_in_fal(i)
      );
  end generate;

  O_psram_cs_n(0) <= cs_n_tbuf;
  O_psram_cs_n(1) <= '1';

  IO_psram_rwds(0) <= rwds_tbuf when rwds_oen_tbuf = '0' else 'Z';
  IO_psram_rwds(1) <= 'Z';

  gen_dq_io : for i in 0 to 7 generate
    IO_psram_dq(i) <= dq_out_tbuf(i) when dq_oen_tbuf(i) = '0' else 'Z';
  end generate;
  IO_psram_dq(15 downto 8) <= (others => 'Z');

  O_psram_ck(0) <= ck_tbuf;
  O_psram_ck(1) <= '0';
end architecture;
