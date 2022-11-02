audio related tuning for UP board  [UP-GWS01-A20-1432-A11](https://www.mouser.sk/ProductDetail/AAEON-UP/UP-GWS01-A20-1432-A11?qs=sGAEpiMZZMv0NwlthflBi5gjgar2Kmx4s6XR5W%252BBCeg%3D)

kernels does not even have any local console - ssh only
    # jitterdebugger during 16@44 roon playback ; kernel 6.1-rc3-RT2
    # cpu3 = usb
    # cpu1 = eth
    #
    affinity: 0-3 = 4 [0xF]
    T: 0 (14885) A: 0 C:    115718 Min:         3 Avg:    6.01 Max:        27
    T: 1 (14886) A: 1 C:    115710 Min:         4 Avg:    6.14 Max:        39
    T: 2 (14887) A: 2 C:    115702 Min:         4 Avg:    5.02 Max:        32
    T: 3 (14888) A: 3 C:    115694 Min:         4 Avg:    5.02 Max:        31
    
