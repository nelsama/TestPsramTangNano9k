--------------------------------------------------------------------------------
-- psram_sram_wrapper.vhd
-- Wrapper que oculta la máquina de estados del controlador PSRAM y
-- presenta una interfaz de memoria estática síncrona (SRAM-like).
--
-- Interfaz de usuario (síncrona con clk):
--   READ:  cs='1', addr, we='0'  (pulso 1 ciclo) → esperar wait_n='1' → dout válido
--   WRITE: cs='1', addr, we='1', din  (pulso 1 ciclo) → esperar wait_n='1'
--
-- La transacción se captura en el flanco de subida cuando cs='1'.
-- wait_n='1' indica que el wrapper está libre (IDLE).
-- wait_n='0' indica operación en curso.
-- La CPU solo necesita mantener la transacción: pone cs='1' UN ciclo y espera.
-- Puede cambiar addr/din/we inmediatamente después.
--
-- Tiempos desde que la CPU pone cs='1' (LATENCY=3, @81 MHz):
--   Escritura: completada en 7 ciclos (~86 ns) la mayoría, 10 ciclos (~123 ns) si hay refresco
--   Lectura:   completada en 12 ciclos (~148 ns) la mayoría, 15 ciclos (~185 ns) si hay refresco
-- Estos son los ciclos desde que la CPU ve cs='1' hasta que ve wait_n='1'.
--
-- La CPU NO ve señales read/write/busy/byte_write. Solo cs, addr, we, din, dout, wait_n.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity psram_sram_wrapper is
  generic (
    FREQ    : integer := 81000000;  -- Frecuencia del reloj (Hz)
    LATENCY : integer := 3          -- Latencia HyperRAM (3=83MHz .. 6=166MHz)
  );
  port (
    -- Relojes
    clk         : in  std_logic;    -- Reloj principal (81 MHz)
    clk_p       : in  std_logic;    -- Reloj desfasado 90° (para DDR)
    resetn      : in  std_logic;    -- Reset activo bajo

    -- Interfaz SRAM-like (todo sincrono con clk, transacción inicia con cs='1')
    addr        : in  std_logic_vector(21 downto 0);  -- Dirección de byte (4 MB)
    din         : in  std_logic_vector(7 downto 0);   -- Dato a escribir (byte)
    dout        : out std_logic_vector(7 downto 0);   -- Dato leído (byte)
    cs          : in  std_logic;    -- Chip select (pulso 1 ciclo = start)
    we          : in  std_logic;    -- 1=escritura, 0=lectura
    wait_n      : out std_logic;    -- 1=IDLE(listo), 0=ocupado

    -- Interfaz física PSRAM (pasa al controlador)
    O_psram_ck      : out   std_logic_vector(1 downto 0);
    O_psram_ck_n    : out   std_logic_vector(1 downto 0);
    IO_psram_rwds   : inout std_logic_vector(1 downto 0);
    IO_psram_dq     : inout std_logic_vector(15 downto 0);
    O_psram_reset_n : out   std_logic_vector(1 downto 0);
    O_psram_cs_n    : out   std_logic_vector(1 downto 0)
  );
end entity;

architecture rtl of psram_sram_wrapper is

  -- Tipos para la FSM interna (oculta del usuario)
  type state_t is (IDLE, WAIT_BUSY);
  signal state, state_next : state_t := IDLE;

  -- Registros de captura de la transacción
  signal op_read  : std_logic := '0';
  signal op_addr  : std_logic_vector(21 downto 0) := (others => '0');

  -- Señales de conexión al controlador
  signal ctrl_read       : std_logic := '0';
  signal ctrl_write      : std_logic := '0';
  signal ctrl_addr       : std_logic_vector(21 downto 0) := (others => '0');
  signal ctrl_din        : std_logic_vector(15 downto 0) := (others => '0');
  signal ctrl_byte_write : std_logic := '0';
  signal ctrl_dout       : std_logic_vector(15 downto 0);
  signal ctrl_busy       : std_logic;

  -- Para detectar flanco descendente de busy
  signal busy_r : std_logic := '0';

  -- wait_n registrado
  signal wait_n_reg : std_logic := '1';

begin

  --------------------------------------------------------------------------------
  -- Instancia del controlador PSRAM (el que tiene la FSM real)
  --------------------------------------------------------------------------------
  u_ctrl : entity work.psram_controller
    generic map (
      FREQ    => FREQ,
      LATENCY => LATENCY
    )
    port map (
      clk       => clk,
      clk_p     => clk_p,
      resetn    => resetn,

      read      => ctrl_read,
      write     => ctrl_write,
      addr      => ctrl_addr,
      din       => ctrl_din,
      byte_write => ctrl_byte_write,
      dout      => ctrl_dout,
      busy      => ctrl_busy,

      O_psram_ck  => O_psram_ck,
      IO_psram_rwds => IO_psram_rwds,
      IO_psram_dq => IO_psram_dq,
      O_psram_cs_n => O_psram_cs_n
    );

  --------------------------------------------------------------------------------
  -- Señales que el controlador no maneja: reset y clock negado
  --------------------------------------------------------------------------------
  O_psram_reset_n <= (others => resetn);
  O_psram_ck_n    <= (others => '0');

  --------------------------------------------------------------------------------
  -- Lógica combinacional del estado siguiente
  --------------------------------------------------------------------------------
  process(all)
  begin
    state_next <= state;  -- por defecto se mantiene

    case state is
      when IDLE =>
        if cs = '1' then
          state_next <= WAIT_BUSY;
        end if;

      when WAIT_BUSY =>
        if busy_r = '1' and ctrl_busy = '0' then
          state_next <= IDLE;
        end if;
    end case;

    -- Reset asíncrono
    if resetn = '0' then
      state_next <= IDLE;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Lógica secuencial: registros de estado, captura, comandos
  --------------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      -- Registrar estado
      state <= state_next;

      -- Registrar busy para detectar flanco descendente
      busy_r <= ctrl_busy;

      -- wait_n registrado: '1' cuando IDLE
      wait_n_reg <= '1' when state_next = IDLE else '0';

      -- Por defecto, las señales de comando están en '0'
      ctrl_read  <= '0';
      ctrl_write <= '0';

      case state is

        ------------------------------------------------------------------------
        -- IDLE: Iniciar transacción si cs='1'
        ------------------------------------------------------------------------
        when IDLE =>
          if cs = '1' then
            op_addr   <= addr;
            op_read   <= not we;
            ctrl_addr <= addr;

            if we = '1' then
              -- ESCRITURA: colocar byte en la posición correcta (según addr(0))
              if addr(0) = '0' then
                ctrl_din <= x"00" & din;
              else
                ctrl_din <= din & x"00";
              end if;
              ctrl_byte_write <= '1';
              ctrl_write      <= '1';
            else
              -- LECTURA
              ctrl_byte_write <= '0';
              ctrl_read       <= '1';
            end if;
          end if;

        ------------------------------------------------------------------------
        -- WAIT_BUSY: Esperar que el controlador termine (sin hacer nada)
        ------------------------------------------------------------------------
        when WAIT_BUSY =>
          null;

      end case;

      -- Reset asíncrono
      if resetn = '0' then
        state      <= IDLE;
        state_next <= IDLE;
        ctrl_read  <= '0';
        ctrl_write <= '0';
        op_read    <= '0';
        wait_n_reg <= '1';
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- Salida dout (se registra cuando cae busy)
  --------------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if state_next = IDLE and state = WAIT_BUSY then
        -- Transición WAIT_BUSY → IDLE: capturar dato si fue lectura
        if op_read = '1' then
          if op_addr(0) = '0' then
            dout <= ctrl_dout(7 downto 0);
          else
            dout <= ctrl_dout(15 downto 8);
          end if;
        end if;
      end if;
    end if;
  end process;

  --------------------------------------------------------------------------------
  -- wait_n: registrado
  --------------------------------------------------------------------------------
  wait_n <= wait_n_reg;

end architecture;
