# PhotonCLI: Zephyr RTOS Morse Code Transmitter

## Overview

PhotonCLI is a multi-threaded Zephyr RTOS application that translates
command-line text input into optical Morse code signals using the onboard LED.
The project demonstrates the decoupling of user interface logic from hardware
timing constraints by utilizing Zephyr's Shell subsystem and Inter-Process
Communication (IPC) primitives.

Designed and tested on the STM32 Nucleo L433RC-P, the application requires no
external wiring or sensor arrays.

## RTOS Architecture

The system is built on a deferred-processing architecture to ensure the
command-line interface remains non-blocking during optical transmission.

* **Zephyr Shell Subsystem:** Provides a standard terminal environment over the
  UART Virtual COM port. Parses incoming strings and validates alphanumeric
  characters.
* **Message Queues (IPC):** A `k_msgq` acts as a thread-safe buffer between the
  shell and the hardware controller. User inputs are packaged into structs and
  placed in the queue, preventing race conditions or memory corruption.
* **Worker Thread Execution:** A dedicated background thread indefinitely blocks
  on the message queue. Upon receiving a payload, it iterates through the
  string, references the static Morse dictionary, and executes hardware toggles
  with precise kernel sleep delays.

## Hardware Requirements

* STM32 Nucleo L433RC-P (or equivalent Zephyr-supported development board)
* Onboard User LED (mapped to Devicetree alias `led0`)
* Micro-USB cable for ST-LINK Virtual COM port and flashing

## Software Dependencies

* Zephyr RTOS (v4.4.0 or newer)
* Zephyr SDK cross-compilers (`arm-zephyr-eabi`)
* `west` meta-tool
* OpenOCD (for flashing and debugging)
* `picocom` (or equivalent serial terminal)

## Building and Flashing

The project utilizes standard Zephyr build commands and can be managed via the
provided `Justfile` or directly using `west`.

To perform a clean build and flash to the Nucleo board:

```bash
# Generate the build system and compile the binary
just build

# Flash the firmware using the onboard ST-LINK
just flash
```

This assumes that you have [`just`](https://github.com/casey/just) installed. If
not then use the below commands.

```bash
# Generate the build system and compile the binary
west build -p always -b nucleo_l433rc_p .

# Flash the firmware using the onboard ST-LINK
west flash --runner openocd
```

> [!IMPORTANT]
> Before running the above commands, make sure the Zephyr Virtual Environment is
> activated

## Usage

Once flashed, connect to the board's Virtual COM port at a baud rate of 115200:

```bash
picocom /dev/ttyACM0 -b 115200
```

Press `Enter` to wake the shell prompt (`uart:~$`).

Invoke the application using the `morse` command followed by the target string.
The shell will queue the message, and the LED will immediately begin
transmission.

### Examples

```text
uart:~$ morse SOS
Message queued for transmission.

uart:~$ morse "HELLO WORLD"
Message queued for transmission.

uart:~$ morse "TEST 123"
Message queued for transmission.
```

### Supported Characters

* Uppercase and lowercase alphabetic characters (`A-Z`, `a-z`)
* Numeric digits (`0-9`)
* Space character (processed as an inter-word delay)
* Unrecognized special characters are safely ignored by the parser.

## Timing Specification

The transmission strictly adheres to standard ITU Morse code timing ratios. The
base unit is defined as 100 milliseconds.

* **Dot:** 1 unit (100ms LED ON)
* **Dash:** 3 units (300ms LED ON)
* **Intra-character gap:** 1 unit (100ms LED OFF)
* **Inter-character gap:** 3 units (300ms LED OFF)
* **Inter-word gap:** 7 units (700ms LED OFF)

## Author

Vaishnav Sabari Girish

## License

MIT License
