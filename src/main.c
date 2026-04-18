#include <zephyr/kernel.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/shell/shell.h>

// LED
#define LED0_NODE DT_ALIAS(led0)

static const struct gpio_dt_spec led = GPIO_DT_SPEC_GET(LED0_NODE, gpios);

#define MAX_MSG_LEN 32

struct morse_msg {
  char text[MAX_MSG_LEN]; 
};

/* Define the Message Queue
* Name: morse_queue
* Data size: Size of the struct
* Max items: 5 messages
* Alignment: 4 bytes
*/
K_MSGQ_DEFINE(morse_queue, sizeof(struct morse_msg), 5, 4);

const char *morse_letters[26] = {
  ".-", "-...", "-.-.", "-..",
  ".", "..-.", "--.", "....",
  "..", ".---", "-.-", ".-..",
  "--", "-.", "---", ".--.",
  "--.-", ".-.", "...", "-",
  "..-", "...-", ".--", "-..-", 
  "-.--", "--.."
};

const char *morse_numbers[10] = {
  "-----", ".----", "..---", "...--", 
  "....-", ".....", "-....", "--...",
  "---..", "----."
};

// Worker thread
void morse_worker_thread(void) {
  uint8_t base_unit_ms = 100;

  struct morse_msg received_msg;

  while (1) {
    // Wait until a message arrives in queue
    k_msgq_get(&morse_queue, &received_msg, K_FOREVER);

    for (char *p = received_msg.text; *p != '\0'; p++) {
      char c = *p;

      if (c == ' ') {
        k_msleep(7 * base_unit_ms);
        continue;
      }

      const char *sequence = NULL;
      if (c >= 'A' && c <= 'Z') {
        sequence = morse_letters[c - 'A'];
      } else if (c >= 'a' && c <= 'z') {
        sequence = morse_letters[c - 'a'];
      } else if (c >= '0' && c <= '9') {
        sequence = morse_numbers[c - '0'];
      } else {
        continue;
      }

      for (int j = 0; j < strlen(sequence); j++) {
        
        gpio_pin_set_dt(&led, 1);

        if (sequence[j] == '.') {
          k_msleep(1 * base_unit_ms);
        } else if (sequence[j] == '-') {
          k_msleep(3 * base_unit_ms);
        }

        gpio_pin_set_dt(&led, 0);

        k_msleep(1 * base_unit_ms);
      }
      k_msleep(2 * base_unit_ms);
    }
  }
}

// Register the worker thread with the OS
K_THREAD_DEFINE(morse_worker_id, 1024, morse_worker_thread, NULL, NULL, NULL, 7, 0, 0);

// Shell commands 
static int cmd_morse(const struct shell *sh, size_t argc, char **argv) {
  if (argc < 2) {
    shell_print(sh, "Usage: morse <string>");
    return -1;
  }

  struct morse_msg payload;

  strncpy(payload.text, argv[1], MAX_MSG_LEN - 1);

  payload.text[MAX_MSG_LEN - 1] = '\0';

  if (k_msgq_put(&morse_queue, &payload, K_NO_WAIT) != 0) {
    shell_print(sh, "ERROR: Queue is full");  
  } else {
    shell_print(sh, "Message queued for transmission");
  }

  return 0;
}

SHELL_CMD_REGISTER(morse, NULL, "Transmit a string via optical morse code", cmd_morse);



int main(void)
{
  if (!gpio_is_ready_dt(&led)) {
    return 0;
  }

  gpio_pin_configure_dt(&led, GPIO_OUTPUT_INACTIVE);

  k_sleep(K_FOREVER);

  return 0;
}
