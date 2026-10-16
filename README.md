# Módulo de Prueba PSRAM para Tang Nano 9K

## Descripción

Este proyecto implementa un módulo de prueba para el core de PSRAM embebida de la Tang Nano 9K. El módulo realiza operaciones de escritura y lectura en la memoria PSRAM y muestra el estado mediante 6 LEDs.

## Características

- ✅ Verificación de calibración de PSRAM
- ✅ Escritura de datos de prueba en memoria
- ✅ Lectura y verificación de datos
- ✅ Indicación visual mediante LEDs
- ✅ PLL configurado para generar relojes de 81 MHz y 162 MHz desde 27 MHz

## Arquitectura

```
sys_clk (27 MHz) -> PLL -> 81 MHz (clk) -> PSRAM Core
                        -> 162 MHz (memory_clk) -> PSRAM Core
                        
PSRAM Core <-> Controlador de Prueba <-> LEDs
```

## Archivos del Proyecto

- **`psram_test_top.vhd`**: Módulo principal (top-level) con lógica de prueba
- **`gowin_rpll.vhd`**: Configuración del PLL
- **`psram_test.cst`**: Archivo de constraints (mapeo de pines)
- **`psram_memory_interface_hs/`**: Core de PSRAM generado por Gowin

## Mapeo de LEDs

| LED | Pin | Función                          | Estado                           |
|-----|-----|----------------------------------|----------------------------------|
| 0   | 10  | Calibración PSRAM                | ON = Calibración completa        |
| 1   | 11  | Escritura completada             | ON = Escritura exitosa           |
| 2   | 13  | Lectura verificada               | ON = Dato leído coincide         |
| 3   | 14  | Error detectado                  | ON = Error en prueba             |
| 4   | 15  | Proceso activo                   | Parpadea durante operaciones     |
| 5   | 16  | PLL Lock                         | ON = PLL sincronizado            |

## Secuencia de Prueba

1. **Reset**: Sistema en reset, todos los LEDs apagados excepto LED5 si PLL está listo
2. **Espera de Calibración**: LED4 parpadea, esperando LED0
3. **Calibración OK**: LED0 se enciende
4. **Escritura**: Se escribe `0xDEADBEEF` en dirección `0x00000`
5. **Escritura Completa**: LED1 se enciende
6. **Lectura**: Se lee la dirección `0x00000`
7. **Verificación**: 
   - Si el dato coincide: LED2 se enciende (✓ Prueba exitosa)
   - Si no coincide: LED3 se enciende (✗ Error)
8. **Fin**: LED4 deja de parpadear

## Interpretación de Resultados

### ✅ Prueba Exitosa
```
LED0: ████ ON  - Calibración OK
LED1: ████ ON  - Escritura OK
LED2: ████ ON  - Lectura OK
LED3: ░░░░ OFF - Sin errores
LED4: ░░░░ OFF - Proceso completo
LED5: ████ ON  - PLL Lock
```

### ❌ Error en Calibración
```
LED0: ░░░░ OFF - Calibración fallida
LED4: ▓▓▓▓ Parpadea continuamente
```

### ❌ Error en Lectura
```
LED0: ████ ON  - Calibración OK
LED1: ████ ON  - Escritura OK
LED2: ░░░░ OFF - Lectura no coincide
LED3: ████ ON  - Error detectado
LED5: ████ ON  - PLL Lock
```

## Configuración de Hardware

### Especificaciones del Core PSRAM

- **Tipo de memoria**: W955D8MBYA (64 Mbit / 8 MB)
- **Ancho de bus**: 8 bits
- **Modo burst**: 32 bytes
- **Frecuencia de memoria**: 162 MHz
- **Latencia inicial**: 6 ciclos
- **Direccionamiento**: 21 bits (2M direcciones x 32 bits)

### Configuración del PLL

- **Entrada**: 27 MHz (reloj onboard)
- **Salida 1 (clkout)**: 81 MHz
- **Salida 2 (clkoutd)**: 162 MHz
- **VCO**: 648 MHz

Cálculo:
```
VCO = FCLKIN × FBDIV / IDIV = 27 × 24 / 1 = 648 MHz
CLKOUT = VCO / ODIV = 648 / 8 = 81 MHz
CLKOUTD = CLKOUT × 2 = 162 MHz
```

## Instrucciones de Uso

### 1. Generar el Core de PSRAM (si no está generado)

En Gowin IDE:
1. Tools → IP Core Generator
2. Seleccionar "PSRAM_HS"
3. Configurar:
   - Memory Type: W955D8MBYA
   - Data Width: 8 bits
   - Address Width: 21 bits
   - Memory Clock: 162 MHz
   - Burst Mode: 32
4. Generar y guardar como `PSRAM_Memory_Interface_HS_Top`

### 2. Agregar Archivos al Proyecto

1. Abrir el proyecto en Gowin IDE
2. Agregar los archivos:
   - `src/psram_test_top.vhd` (marcar como Top Module)
   - `src/gowin_rpll.vhd`
   - `src/psram_memory_interface_hs/psram_memory_interface_hs.vhd`
3. Agregar el archivo de constraints:
   - `src/psram_test.cst`

### 3. Compilar y Programar

1. Synthesize → Place & Route
2. Programmer → Cargar bitstream
3. Program al FPGA

### 4. Observar Resultados

- Pulsar el botón de reset (S1)
- Observar la secuencia de LEDs
- LED2 encendido = Prueba exitosa ✓

## Modificaciones Posibles

### Cambiar Datos de Prueba

Editar en [`psram_test_top.vhd`](src/psram_test_top.vhd):

```vhdl
constant TEST_DATA_1 : std_logic_vector(31 downto 0) := x"DEADBEEF";
constant TEST_DATA_2 : std_logic_vector(31 downto 0) := x"12345678";
constant TEST_DATA_3 : std_logic_vector(31 downto 0) := x"A5A5A5A5";
```

### Cambiar Direcciones de Prueba

```vhdl
constant TEST_ADDR_1 : std_logic_vector(20 downto 0) := "000000000000000000000";
constant TEST_ADDR_2 : std_logic_vector(20 downto 0) := "000000000000000000100";
```

### Agregar Más Pruebas

Ampliar la máquina de estados en la sección `ST_SUCCESS` para realizar múltiples escrituras/lecturas en loop.

## Señales Importantes

### Interfaz PSRAM

- **`cmd`**: Comando (`'0'` = Write, `'1'` = Read)
- **`cmd_en`**: Enable de comando (pulso de 1 ciclo)
- **`wr_data[31:0]`**: Datos a escribir (32 bits)
- **`rd_data[31:0]`**: Datos leídos (32 bits)
- **`rd_data_valid`**: Indica que `rd_data` es válido
- **`addr[20:0]`**: Dirección (21 bits)
- **`init_calib`**: Indica calibración completa
- **`data_mask[3:0]`**: Máscara de bytes (`"0000"` = todos habilitados)

### Timing de Operaciones

**Escritura**:
1. Colocar `addr` y `wr_data`
2. Poner `cmd = '0'`, `cmd_en = '1'` por 1 ciclo
3. Esperar ~0.5 ms antes de siguiente operación

**Lectura**:
1. Colocar `addr`
2. Poner `cmd = '1'`, `cmd_en = '1'` por 1 ciclo
3. Esperar a `rd_data_valid = '1'`
4. Leer `rd_data`

## Troubleshooting

### LED0 no enciende (calibración falla)
- Verificar conexiones PSRAM en constraints
- Verificar que PLL genera 162 MHz correctamente
- Revisar configuración del core PSRAM

### LED3 enciende (error en comparación)
- PSRAM funciona pero datos no coinciden
- Posible problema de timing
- Revisar configuración de latencia del core

### Ningún LED enciende
- Verificar PLL (LED5 debe encender)
- Revisar reset (botón S1)
- Verificar bitstream cargado correctamente

## Recursos Utilizados

- **LUTs**: ~700
- **Registers**: ~410
- **Block RAM**: 2
- **PLLs**: 1

## Referencias

- [Tang Nano 9K Schematic](https://dl.sipeed.com/shareURL/TANG/Nano%209K/2_Schematic)
- [Gowin PSRAM HS IP Core User Guide](http://cdn.gowinsemi.com.cn/UG998.pdf)
- [GW1NR Datasheet](http://cdn.gowinsemi.com.cn/DS117.pdf)

## Licencia

Este código de ejemplo está disponible para uso educativo y de desarrollo.

---
**Nota**: Este es un módulo de prueba básico. Para aplicaciones de producción, implementar manejo de errores más robusto y secuencias de prueba más exhaustivas.
