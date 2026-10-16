--------------------------------------------------------------------------------
-- Ejemplos Avanzados para Test PSRAM
-- Este archivo contiene fragmentos de código para expandir las pruebas
--------------------------------------------------------------------------------

-- EJEMPLO 1: Prueba de Múltiples Direcciones
--------------------------------------------------------------------------------
-- Agregar al proceso principal en psram_test_top.vhd después de ST_SUCCESS

-- Nueva señal en declaraciones:
-- signal test_count : unsigned(3 downto 0);

-- En la máquina de estados:
when ST_SUCCESS =>
    process_active <= '0';
    -- Incrementar contador de pruebas
    if test_count < 10 then
        test_count <= test_count + 1;
        -- Siguiente dirección (incrementar por 4 bytes)
        test_addr <= test_addr + 4;
        -- Rotar patrón de datos
        test_data <= test_data(30 downto 0) & test_data(31);
        -- Volver a escribir
        wait_counter <= (others => '0');
        state <= ST_WRITE_WAIT;
    end if;
    -- Si test_count = 10, todas las pruebas completadas


-- EJEMPLO 2: Prueba de Patrón Walking Ones
--------------------------------------------------------------------------------
-- Útil para detectar bits pegados

-- Agregar constantes:
-- type test_pattern_array is array (0 to 31) of std_logic_vector(31 downto 0);
-- constant WALKING_ONES : test_pattern_array := (
--     x"00000001", x"00000002", x"00000004", x"00000008",
--     x"00000010", x"00000020", x"00000040", x"00000080",
--     x"00000100", x"00000200", x"00000400", x"00000800",
--     x"00001000", x"00002000", x"00004000", x"00008000",
--     x"00010000", x"00020000", x"00040000", x"00080000",
--     x"00100000", x"00200000", x"00400000", x"00800000",
--     x"01000000", x"02000000", x"04000000", x"08000000",
--     x"10000000", x"20000000", x"40000000", x"80000000"
-- );

-- signal pattern_index : integer range 0 to 31;

-- En ST_WRITE_CMD:
-- test_data <= unsigned(WALKING_ONES(pattern_index));


-- EJEMPLO 3: Prueba de Ráfaga Continua
--------------------------------------------------------------------------------
-- Escribe y lee múltiples palabras en secuencia

when ST_BURST_WRITE =>
    if burst_counter < BURST_LENGTH then
        addr <= std_logic_vector(unsigned(BASE_ADDR) + burst_counter);
        wr_data <= std_logic_vector(to_unsigned(burst_counter, 32));
        cmd <= '0';  -- Write
        cmd_en <= '1';
        burst_counter <= burst_counter + 1;
        state <= ST_BURST_WRITE_WAIT;
    else
        burst_counter <= (others => '0');
        state <= ST_BURST_READ;
    end if;

when ST_BURST_WRITE_WAIT =>
    if wait_counter < x"1000" then
        wait_counter <= wait_counter + 1;
    else
        wait_counter <= (others => '0');
        state <= ST_BURST_WRITE;
    end if;


-- EJEMPLO 4: Prueba de Dirección Completa
--------------------------------------------------------------------------------
-- Barre toda la memoria (¡toma tiempo!)

-- Constantes para barrido de memoria:
-- constant ADDR_START : unsigned(20 downto 0) := (others => '0');
-- constant ADDR_END   : unsigned(20 downto 0) := (others => '1');
-- constant ADDR_STEP  : unsigned(20 downto 0) := to_unsigned(4, 21);

when ST_SWEEP_WRITE =>
    if current_addr <= ADDR_END then
        addr <= std_logic_vector(current_addr);
        wr_data <= std_logic_vector(current_addr) & std_logic_vector(current_addr(10 downto 0));
        cmd <= '0';
        cmd_en <= '1';
        state <= ST_SWEEP_WRITE_WAIT;
    else
        current_addr <= ADDR_START;
        state <= ST_SWEEP_READ;
    end if;

when ST_SWEEP_WRITE_WAIT =>
    if wait_counter < x"800" then
        wait_counter <= wait_counter + 1;
    else
        wait_counter <= (others => '0');
        current_addr <= current_addr + ADDR_STEP;
        state <= ST_SWEEP_WRITE;
    end if;


-- EJEMPLO 5: Contador de Errores
--------------------------------------------------------------------------------
-- Mantiene registro de errores encontrados

-- Señales adicionales:
-- signal error_count : unsigned(15 downto 0);
-- signal total_tests : unsigned(15 downto 0);

when ST_READ_CHECK =>
    total_tests <= total_tests + 1;
    if rd_data = std_logic_vector(expected_data) then
        data_match <= '1';
        state <= ST_NEXT_TEST;
    else
        data_match <= '0';
        error_count <= error_count + 1;
        -- Continuar con más pruebas en lugar de detenerse
        state <= ST_NEXT_TEST;
    end if;

-- Mostrar tasa de error en LEDs:
-- led(3 downto 0) <= std_logic_vector(error_count(3 downto 0));


-- EJEMPLO 6: Test con Diferentes Máscaras de Datos
--------------------------------------------------------------------------------
-- Prueba escritura de bytes individuales

-- Máscaras posibles:
-- data_mask <= "0000";  -- Todos los bytes (32 bits)
-- data_mask <= "0001";  -- Solo bits 31-24
-- data_mask <= "0010";  -- Solo bits 23-16
-- data_mask <= "0100";  -- Solo bits 15-8
-- data_mask <= "1000";  -- Solo bits 7-0

when ST_MASK_TEST =>
    case mask_pattern is
        when "00" =>
            data_mask <= "0001";
            wr_data <= x"AA000000";
        when "01" =>
            data_mask <= "0010";
            wr_data <= x"00BB0000";
        when "10" =>
            data_mask <= "0100";
            wr_data <= x"0000CC00";
        when "11" =>
            data_mask <= "1000";
            wr_data <= x"000000DD";
        when others =>
            data_mask <= "0000";
    end case;


-- EJEMPLO 7: Medición de Latencia
--------------------------------------------------------------------------------
-- Mide el tiempo entre cmd_en y rd_data_valid

-- Señales:
-- signal latency_counter : unsigned(15 downto 0);
-- signal min_latency : unsigned(15 downto 0) := (others => '1');
-- signal max_latency : unsigned(15 downto 0) := (others => '0');

when ST_READ_CMD =>
    latency_counter <= (others => '0');
    addr <= std_logic_vector(test_addr);
    cmd <= '1';
    cmd_en <= '1';
    state <= ST_READ_MEASURE_LATENCY;

when ST_READ_MEASURE_LATENCY =>
    latency_counter <= latency_counter + 1;
    if rd_data_valid = '1' then
        -- Actualizar estadísticas
        if latency_counter < min_latency then
            min_latency <= latency_counter;
        end if;
        if latency_counter > max_latency then
            max_latency <= latency_counter;
        end if;
        state <= ST_READ_CHECK;
    end if;


-- EJEMPLO 8: Prueba de Estrés
--------------------------------------------------------------------------------
-- Lectura/escritura continua a máxima velocidad

when ST_STRESS_TEST =>
    if stress_counter(0) = '0' then
        -- Escritura
        addr <= std_logic_vector(stress_counter(20 downto 0));
        wr_data <= std_logic_vector(stress_counter);
        cmd <= '0';
        cmd_en <= '1';
    else
        -- Lectura
        addr <= std_logic_vector((stress_counter - 1)(20 downto 0));
        cmd <= '1';
        cmd_en <= '1';
    end if;
    stress_counter <= stress_counter + 1;
    
    -- Correr por cierto tiempo o número de operaciones
    if stress_counter >= STRESS_CYCLES then
        state <= ST_STRESS_COMPLETE;
    end if;


-- EJEMPLO 9: Patrón Checkerboard
--------------------------------------------------------------------------------
-- Prueba con patrón alternante

-- Patrones:
-- constant CHECKERBOARD_1 : std_logic_vector(31 downto 0) := x"AAAAAAAA";
-- constant CHECKERBOARD_2 : std_logic_vector(31 downto 0) := x"55555555";

when ST_CHECKERBOARD_WRITE =>
    if addr_counter(0) = '0' then
        wr_data <= CHECKERBOARD_1;
    else
        wr_data <= CHECKERBOARD_2;
    end if;
    addr <= std_logic_vector(addr_counter);
    cmd <= '0';
    cmd_en <= '1';
    addr_counter <= addr_counter + 1;
    state <= ST_CHECKERBOARD_WAIT;


-- EJEMPLO 10: Puerto Serie para Reportes
--------------------------------------------------------------------------------
-- Agregar UART para reportar resultados detallados

-- Componente UART (necesitas agregarlo al proyecto):
-- uart_tx_inst: uart_tx
--     generic map (
--         BAUD_RATE => 115200,
--         CLK_FREQ  => 81000000
--     )
--     port map (
--         clk      => clk_81,
--         rst_n    => rst_n,
--         tx_data  => uart_data,
--         tx_valid => uart_valid,
--         tx_ready => uart_ready,
--         tx       => uart_tx_pin
--     );

-- Para reportar resultados:
when ST_REPORT_RESULT =>
    case report_state is
        when 0 =>
            -- Enviar mensaje "Test: "
            uart_data <= x"54";  -- 'T'
            uart_valid <= '1';
            if uart_ready = '1' then
                report_state <= report_state + 1;
            end if;
        when 1 =>
            -- Enviar resultado
            if data_match = '1' then
                uart_data <= x"4F";  -- 'O'
                uart_data <= x"4B";  -- 'K'
            else
                uart_data <= x"45";  -- 'E'
                uart_data <= x"52";  -- 'R'
            end if;
        -- ... más caracteres
    end case;


--------------------------------------------------------------------------------
-- Notas Importantes:
--------------------------------------------------------------------------------
-- 1. Los ejemplos anteriores son fragmentos, no código completo
-- 2. Necesitas declarar todas las señales en la sección de arquitectura
-- 3. Ajusta los tiempos de espera según tu aplicación
-- 4. Para pruebas extensas, considera usar un procesador soft-core
-- 5. Monitorea el uso de recursos (LUTs, FFs, BRAM)
--------------------------------------------------------------------------------
