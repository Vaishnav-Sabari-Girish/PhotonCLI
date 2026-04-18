build:
    @west build -b nucleo_l433rc_p .

pristine:
    @west build -p always -b nucleo_l433rc_p .

flash:
    @west flash --runner openocd

clean:
    @rm -rf build compile_commands.json
