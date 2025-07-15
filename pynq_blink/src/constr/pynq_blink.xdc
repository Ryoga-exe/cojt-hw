# A9.RADIO_LED0
set_property PACKAGE_PIN A9   [get_ports {RADIO_LED0             }];
# B9.RADIO_LED1
set_property PACKAGE_PIN B9   [get_ports {RADIO_LED1             }];

# Set the bank voltage for IO Bank 26 to 1.8V
set_property IOSTANDARD LVCMOS18 [get_ports -of_objects [get_iobanks 26]];
