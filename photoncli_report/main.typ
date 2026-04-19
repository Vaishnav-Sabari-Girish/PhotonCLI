
#import "@preview/basic-report:0.4.0": *

#show: it => basic-report(
  doc-category: "Project Report",
  doc-title: "PhotonCLI",
  author: "Vaishnav Sabari Girish",
  affiliation: "ECE Department, Jain (Deemed-to-be) University",
  language: "en",
  it
)

#show heading: set text(fill: black, weight: "bold")

= Introduction

Optical data transmission using basic indicators (like LEDs) is a foundational concept in embedded systems. While blinking an LED is trivial, managing long, variable-length optical transmissions without halting the entire microcontroller requires advanced software architecture.

PhotonCLI is a multi-threaded Real-Time Operating System (RTOS) application that translates human-readable command-line text into optical Morse code signals in real-time. By utilizing the Zephyr RTOS Shell subsystem and Message Queues, the project successfully decouples the user interface from the hardware timing constraints.

This project demonstrates the practical application of RTOS paradigms—specifically thread synchronization, deferred processing, and safe Inter-Process Communication (IPC)—on an ARM Cortex-M4 microcontroller.

= Problem Statement and Solution

== The problem with synchronous blocking delays

In standard bare-metal embedded programming (such as Arduino or basic HAL scripts), optical timing is typically achieved using synchronous blocking delays (e.g., `HAL_Delay()`). Because Morse code requires precise, extended periods of pausing (often lasting several seconds for long strings), the microcontroller spends the vast majority of its CPU cycles trapped in these delay loops.

This creates a severe bottleneck: while the system is blinking the LED, it is entirely deaf to new inputs, unable to process sensor data, and unable to interact with the user. This "busy-waiting" approach is unacceptable in modern, responsive embedded systems.

== The solution: PhotonCLI architecture

PhotonCLI solves this concurrency problem by implementing a deferred-processing RTOS architecture:
1. *Background Threading*: The hardware timing is moved to a completely independent worker thread that operates in the background.

2. *Message Queues*: The user interface (Shell) and the hardware controller (Worker Thread) communicate exclusively through a thread-safe First-In-First-Out (FIFO) Message Queue.

3. *Non-blocking UI*: The user can queue multiple messages sequentially without the terminal ever freezing, regardless of how long the optical transmission takes.

= Theory

== Standard Morse Code Timing Ratios 

The system adheres to the International Telecommunication Union (ITU) standard for Morse code, which relies on a single relative time unit to dictate all transmission speeds. In PhotonCLI, the base unit is defined as 100 milliseconds ($100~"ms"$).

The timing rules are as follows:

- *Dot*: 1 unit ($100~"ms"$ LED ON)
- *Dash*: 3 units ($300~"ms"$ LED ON)
- *Intra-character gap (between dots/dashes)*: 1 unit ($100~"ms"$ LED OFF)
- *Inter-character gap (between letters)*: 3 units ($300~"ms"$ LED OFF)
- *Inter-word gap (space character)*: 7 units ($700~"ms"$ LED OFF)

== Real-Time Operating Systems (RTOS) and Scheduling

Instead of a single `while(1)` loop, the Zephyr kernel scheduler allocates CPU time to multiple threads based on priority. When the Morse worker thread calls `k_msleep()`, it does not block the CPU. Instead, it yields control back to the kernel, allowing the Shell thread to continue accepting user input.

== Inter-Process Communication (IPC)

A Zephyr Message Queue (`k_msgq`) is used to pass data across thread boundaries safely. It acts as a ring buffer. The shell acts as the Producer (putting text payloads into the queue), and the background thread acts as the Consumer (pulling text out of the queue).

== ASCII_based Character Parsing 

To optimize memory, the system uses algorithmic ASCII mapping rather than a hash map. By subtracting the ASCII value of `'A'` from an incoming uppercase character (e.g., `'C' - 'A' = 2`), the system instantly computes the correct array index for the `morse_letters` dictionary.

= Methodology 

== System Architecture 

The PhotonCLI system consists of the following isolated software blocks running on an STM32 Nucleo L433RC-P:

- *UART Driver*: Handles physical serial communication.
- *Zephyr Shell Subsystem*: Parses UART data into `argc`/`argv` command arrays.
- *IPC Message Queue*: A 5-item deep buffer storing 32-byte message `structs`
- *Morse Worker Thread*: A static thread initialized with a priority of 7 and a stack size of 1024 bytes.
- *GPIO Controller*: Toggles the `led0` Devicetree alias.

== Execution Process 

The system operates with the following workflow : 
1. The user types `morse <string>` into the serial terminal.
2. The Zephyr Shell intercepts the command and invokes `cmd_morse`
3. The command arguments are safely copied into a `morse_msg` struct payload.
4. The payload is pushed to the `morse_queue` using a non-blocking `K_NO_WAIT` flag.
5. The `morse_worker_thread`, which was suspended in `K_FOREVER`, wakes up.
6. The thread parses the string, iterating character by character.
7. Alphanumeric characters are converted to dots and dashes using the lookup tables, and `gpio_pin_set_dt` is used alongside `k_msleep` to transmit the optical signal.

== Hardware Utilization 

Unlike complex sensor arrays, PhotonCLI relies entirely on the Nucleo board's internal peripherals:

#figure(
  table(
    columns: (auto, auto),
    align: horizon,
    table.header(
      [*Component*], [*Purpose*]
    ),
    [*STM32L433 CPU*], [Core processor executing the Zephyr kernel],
    [*Virtual COM Port*], [ST-LINK USB-to-UART bridge for the Shell CLI], 
    [*User LED (Green)*], [Connected internally to pin PA5 (Alias `led0`)]
  ), 
  caption: [Hardware Components]
)<hwc>

== Memory and Buffer Protection 

To ensure thread safety and prevent memory corruption (buffer overflows) from long user inputs, the system implements strict bounds checking:

- The payload struct is strictly limited to `MAX_MSG_LEN` (32 bytes).
- The `strncpy()` function is used to securely copy user input into the queue buffer.
- The final byte of the buffer is explicitly forced to a null terminator `'\0'` to guarantee safe string iteration in the worker thread.

= Tech Stack 

== Hardware 

- *Microcontroller*: STM32 Nucleo L433RC-P (32-bit ARM Cortex-M4)
- *Output Device*: Onboard Green LED
- *Interface*: Micro-USB (ST-LINK V2-1)

== Software (Firmware and Libraries)

The firmware is written in standard C, utilizing the Zephyr RTOS API.

=== Core Framework

*Zephyr RTOS* provides the real-time kernel, multi-threading, GPIO drivers, and IPC Message Queue primitives (`k_msgq_put`, `k_msgq_get`).

=== Command Line Interface (CLI)

*Zephyr Shell Subsystem* provides a fully interactive, VT100-compatible terminal over UART, featuring auto-completion, command history, and dynamic argument parsing via the `SHELL_CMD_REGISTER` macro.

=== Build system and Toolchain 

- *`west`*: The official Zephyr meta-tool used for workspace management and invoking `CMake`.
- *Zephyr SDK*: Provides the `arm-zephyr-eabi-gcc` cross-compiler.

=== Development Tools 

- *OpenOCD*: Handles the physical flashing of the `.elf` binary to the STM32 flash memory via the ST-LINK.
- *Clangd*: Language server utilizing `compile_commands.json` for precise C diagnostics and Zephyr Devicetree macro expansion.

= Example Interactions 

Because the system operates headless via a Virtual COM port, user interaction is strictly terminal-based.

== Standard Transmission 

When a user queues a standard message, the shell returns control instantly while the LED begins blinking in the background:

```text
uart:~$ morse "HELLO WORLD"
Message queued for transmission.
uart:~$
```

== Queue Saturation 

If the user queues more than 5 messages before the worker thread finishes transmitting the first one, the IPC buffer correctly rejects the overflow without crashing the RTOS:

```text
uart:~$ morse "A"
Message queued for transmission.
uart:~$ morse "B"
Message queued for transmission.
...
uart:~$ morse "F"
ERROR: Queue is full
```

= Images 

== UART Terminal (Zephyr Shell)

=== Normal 

#figure(
  image("assets/normal.png", width: 120%),
  caption: [Normal Shell]
)

=== Error 

#figure(
  image("assets/error.png", width: 120%),
  caption: [Error Shell]
)

== STM32 Nucleo L433RC-P 

#figure(
  image("assets/stm32_nucleo.jpg", width: 70%),
  caption: [STM32 Nucleo L433RC-P]
)

#bibliography("refs.bib", full: true, title: "References")
