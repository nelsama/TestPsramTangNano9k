# 📁 Estructura del Proyecto Test_PSRAM

```
Test_PSRAM/
│
├── 📄 Test_PSRAM.gprj              # Proyecto Gowin IDE
├── 📖 README.md                     # Documentación completa
├── 🚀 QUICK_START.md               # Guía rápida de inicio
├── 💡 ADVANCED_EXAMPLES.vhd        # Ejemplos de código avanzado
│
├── 📂 src/                          # Código fuente VHDL
│   ├── psram_test_top.vhd          # ⭐ Módulo principal (TOP)
│   ├── gowin_rpll.vhd              # Configuración PLL
│   ├── psram_test.cst              # Constraints (pines)
│   └── psram_memory_interface_hs/  # Core IP PSRAM
│       ├── psram_memory_interface_hs.vhd
│       ├── psram_memory_interface_hs.ipc
│       └── ...
│
├── 📂 impl/                         # Archivos de implementación
│   └── temp/
│
└── 📂 sim/                          # Simulación
    └── tb_psram_test.vhd           # Testbench
```

---

## 🎯 Archivos Principales

### 1. `psram_test_top.vhd` ⭐
**Módulo principal del sistema**
- Instancia PLL
- Instancia core PSRAM
- Máquina de estados de prueba
- Control de LEDs

### 2. `gowin_rpll.vhd`
**Generador de relojes**
- 27 MHz → 81 MHz (clk)
- 27 MHz → 162 MHz (memory_clk)

### 3. `psram_test.cst`
**Mapeo de pines físicos**
- Clock (pin 52)
- Reset (pin 3)
- LEDs (pines 10, 11, 13, 14, 15, 16)
- PSRAM (pines 42, 48, 49, 76-86)

---

## 🔌 Conexiones de Hardware

### Tang Nano 9K

```
                    ┌─────────────────────────┐
                    │   Tang Nano 9K          │
                    │   GW1NR-9C FPGA         │
                    ├─────────────────────────┤
CLK 27MHz ──────────┤ Pin 52                  │
                    │                         │
Reset (S1) ─────────┤ Pin 3                   │
                    │                         │
LED[0] ─────────────┤ Pin 10  (Calibración)   │
LED[1] ─────────────┤ Pin 11  (Escritura)     │
LED[2] ─────────────┤ Pin 13  (Lectura OK)    │
LED[3] ─────────────┤ Pin 14  (Error)         │
LED[4] ─────────────┤ Pin 15  (Proceso)       │
LED[5] ─────────────┤ Pin 16  (PLL Lock)      │
                    │                         │
                    │    PSRAM Interna        │
                    │    (64 Mbit)            │
                    │                         │
USB-C ──────────────┤ Programación/Debug      │
                    └─────────────────────────┘
```

---

## 🔄 Flujo de Trabajo

```
┌──────────────┐
│  Editar      │
│  VHDL        │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Synthesize   │  Gowin IDE
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Place &      │
│ Route        │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Generate     │
│ Bitstream    │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Program      │
│ FPGA         │
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Test con     │
│ LEDs         │
└──────────────┘
```

---

## 📊 Máquina de Estados

```
    ┌───────┐
    │ RESET │
    └───┬───┘
        │
        ▼
  ┌──────────────┐
  │ WAIT_CALIB   │ ◄─── Espera init_calib = '1'
  └──────┬───────┘
         │ Calibración OK
         ▼
  ┌──────────────┐
  │ WRITE_WAIT   │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ WRITE_CMD    │ ◄─── Escribe 0xDEADBEEF
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ WRITE_DONE   │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ READ_WAIT    │
  └──────┬───────┘
         │
         ▼
  ┌──────────────┐
  │ READ_CMD     │ ◄─── Lee dirección
  └──────┬───────┘
         │
         ▼
  ┌───────────────────┐
  │ READ_WAIT_VALID   │ ◄─── Espera rd_data_valid
  └──────┬────────────┘
         │
         ▼
  ┌──────────────┐
  │ READ_CHECK   │ ◄─── Compara datos
  └──────┬───────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌─────────┐ ┌───────┐
│ SUCCESS │ │ ERROR │
└─────────┘ └───────┘
```

---

## 📈 Timeline de Ejecución

```
Tiempo →

0ms          Reset
             │
~1ms         PLL Lock (LED5 ON)
             │
~10ms        Calibración completa (LED0 ON)
             │
~15ms        Escritura enviada (LED1 ON)
             │
~20ms        Lectura enviada
             │
~25ms        Verificación (LED2 ON si OK, LED3 ON si error)
             │
             LED4 deja de parpadear
```

---

## 💾 Datos de Prueba

| Dirección | Valor Escrito | Valor Esperado |
|-----------|---------------|----------------|
| 0x00000   | 0xDEADBEEF   | 0xDEADBEEF     |

*Puede expandirse con más direcciones/patrones*

---

## 🎨 Indicadores LED

### Durante Calibración
```
LED: [5]─[4]─[3]─[2]─[1]─[0]
     [█] [▓] [░] [░] [░] [░]
      │   │
      │   └─ Parpadeando (procesando)
      └───── PLL Lock
```

### Durante Escritura
```
LED: [5]─[4]─[3]─[2]─[1]─[0]
     [█] [▓] [░] [░] [░] [█]
      │   │           │   │
      │   │           │   └─ Calibración OK
      │   │           └───── Escritura OK
      │   └─────────────── Procesando
      └───────────────── PLL Lock
```

### Éxito Final
```
LED: [5]─[4]─[3]─[2]─[1]─[0]
     [█] [░] [░] [█] [█] [█]
      │   │   │   │   │   │
      │   │   │   │   │   └─ Calibración OK
      │   │   │   │   └───── Escritura OK
      │   │   │   └───────── Lectura verificada ✓
      │   │   └───────────── Sin error
      │   └───────────────── Proceso completo
      └───────────────────── PLL Lock

      ¡PRUEBA EXITOSA! 🎉
```

### Error Detectado
```
LED: [5]─[4]─[3]─[2]─[1]─[0]
     [█] [░] [█] [░] [█] [█]
      │   │   │       │   │
      │   │   │       │   └─ Calibración OK
      │   │   │       └───── Escritura OK
      │   │   └───────────── ERROR ⚠️
      │   └───────────────── Proceso completo
      └───────────────────── PLL Lock
```

---

## 🔧 Herramientas Necesarias

- **Gowin IDE** v1.9.12 o superior
- **Tang Nano 9K** (GW1NR-9C)
- **Cable USB-C**
- **6 LEDs externos** (o usar LEDs onboard si disponibles)

---

## 📚 Referencias Rápidas

| Componente | Frecuencia | Descripción |
|------------|-----------|-------------|
| sys_clk    | 27 MHz    | Clock principal placa |
| clk_81     | 81 MHz    | Clock sistema |
| clk_162    | 162 MHz   | Clock PSRAM |

| Señal | Función | Valores |
|-------|---------|---------|
| cmd   | Comando | '0'=Write, '1'=Read |
| cmd_en| Enable  | Pulso 1 ciclo |
| init_calib | Calibración | '1'=Completa |
| rd_data_valid | Validez | '1'=Dato válido |

---

## ✅ Checklist de Compilación

```
□ Archivos VHDL sin errores de sintaxis
□ Core PSRAM generado correctamente
□ PLL configurado (27→81/162 MHz)
□ Archivo .cst con pines correctos
□ Top module establecido
□ Síntesis completada (0 errores)
□ Place & Route completado (0 errores)
□ Bitstream generado
□ FPGA programada
□ Reset aplicado
□ LEDs respondiendo
```

---

**Proyecto creado:** Febrero 2026  
**Target:** Tang Nano 9K (GW1NR-9C)  
**Lenguaje:** VHDL  
**Herramienta:** Gowin IDE

¡Feliz testing! 🚀
