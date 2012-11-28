bus-bootcamp
============

bus_bootcamp

This module contains contains packages of Moose types that enable a perl programmer to develop drivers to talk to different hardware components in an embedded linux environment via GPIO (General Purpose Input Output) lines.

This is accomplished by gaining programmatic access to various buses (SPI, I2C, UART, 1WIRE, usb,).  Send and recieve data to these buses using a unified interface.  Further provide a framework for adding new buses.  Like the Bus Pirate, this is primary a tool used for design and diagnostic purposes.


There are of course some rules but they are reasonable enough assumptions to make in the embedded Linux domain.

1) The Linux Kernel has GPIO enabled

2) You have a Bus Pirate board

That wasn't hard was it.

So the progression of using your hardware with perl goes something like this

minicom <-> bus_pirate <-> some hardware

perl app <-> Bus::Pirate <-> some hardware

perl app <-> GPIO <-> Bus::Pirate test hardware
     	 
perl app <-> GPIO <-> some hardware

Example Scenario: Suppose you have a intergrated circuit (IC) component that gives you the temperature and pressure via an I2C bus.

1) Wire up the circuit and connect the bus pirate to it.

2) Connect to the bus pirate via a terminal emulator such as minicom and discover how the device works

3) Using the knowlegdge gained in step 2 write a perl program that uses the Bus::Pirate module to access the IC via the I2C bus and obtain the temperature.

4) Install the correct Bus GPIO kernel module in this case the GPIO kernel module that allows one to access I2C device via GPIO.

5) Switch from using the Bus::Pirate to GPIO to talk to the device

6) Have a beer!

Save step 6 this is what the initial example and tests are centered around.
