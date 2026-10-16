# Guía Rápida de Inicio - Test PSRAM Tang Nano 9K

## 🚀 Inicio Rápido

### Paso 1: Abrir el Proyecto
1. Abre Gowin IDE
2. File → Open Project → Selecciona `Test_PSRAM.gprj`

### Paso 2: Verificar Archivos
Asegúrate de que estos archivos están en el proyecto:

```
✓ src/psram_test_top.vhd (Top Module)
✓ src/gowin_rpll.vhd
✓ src/psram_memory_interface_hs/psram_memory_interface_hs.vhd
✓ src/psram_test.cst
```

### Paso 3: Configurar Top Module
1. Clic derecho en `psram_test_top.vhd`
2. Seleccionar "Set as Top Module"

### Paso 4: Sintetizar
1. Process → Synthesize ✓
2. Esperar a que complete sin errores

### Paso 5: Place & Route
1. Process → Place & Route ✓
2. Esperar a que complete

### Paso 6: Generar Bitstream
1. El bitstream se genera automáticamente en `impl/pnr/Test_PSRAM.fs`

### Paso 7: Programar FPGA
1. Tools → Programmer
2. Conectar Tang Nano 9K por USB
3. Verificar que el dispositivo aparece
4. Operation Type: SRAM Program (para prueba) o Flash Program (permanente)
5. Add File → Seleccionar `.fs` generado
6. Program/Configure

### Paso 8: Probar
1. Pulsar botón S1 (reset)
2. Observar secuencia de LEDs:
   - LED5 debe encender (PLL Lock)
   - LED4 parpadea (procesando)
   - LED0 enciende (calibración OK)
   - LED1 enciende (escritura OK)
   - LED2 enciende (lectura OK) ✓ ¡ÉXITO!
   - LED4 se apaga (proceso completo)

## 🎯 Resultado Esperado

```
[LED5] ████ ON  → PLL funcionando
[LED4] ░░░░ OFF → Proceso completado
[LED3] ░░░░ OFF → Sin errores
[LED2] ████ ON  → ¡Lectura correcta!
[LED1] ████ ON  → Escritura exitosa
[LED0] ████ ON  → Calibración OK
```

## ❌ Solución de Problemas

### LED0 no enciende
- Verificar conexiones PSRAM en .cst
- Regenerar core PSRAM con configuración correcta

### LED3 enciende (Error)
- PSRAM calibra pero datos no coinciden
- Revisar timing del PLL
- Verificar configuración de memoria

### Solo LED5 enciende
- PLL OK pero no hay calibración
- Verificar core PSRAM incluido en proyecto
- Revisar conexiones físicas

## 📋 Checklist

- [ ] Proyecto abierto en Gowin IDE
- [ ] Core PSRAM generado y en proyecto
- [ ] psram_test_top.vhd marcado como Top
- [ ] Archivo .cst agregado al proyecto
- [ ] Síntesis sin errores
- [ ] Place & Route sin errores
- [ ] Tang Nano 9K conectada
- [ ] Bitstream programado
- [ ] Reset pulsado
- [ ] LED2 encendido (¡Éxito!)

## 🔧 Configuración del PLL

Si necesitas regenerar el PLL:

1. Tools → IP Core Generator
2. Buscar "PLL" → rPLL
3. Configurar:
   - Input Clock: 27 MHz
   - Output Clock 1: 81 MHz
   - Output Clock 2: 162 MHz
   - Device: GW1NR-9C

## 📖 Más Información

Ver [README.md](README.md) completo para:
- Descripción detallada de señales
- Modificaciones avanzadas
- Troubleshooting exhaustivo
- Referencias técnicas

## ⚡ Tips

- **SRAM Program**: Más rápido para pruebas, se borra al desconectar
- **Flash Program**: Permanente, se mantiene después de reset
- Si LED4 parpadea indefinidamente → Calibración en progreso (esperar) o falló
- Todos los LEDs excepto LED3 encendidos = Prueba perfecta ✓

---
¡Disfruta experimentando con la PSRAM! 🎉
