#include <stdint.h>
#include <zephyr/kernel.h>
#include <zephyr/sys/printk.h>

int main(void)
{
    printk("Hello World\n");
    return 0;
}
