audio related tuning for UP board  [UP-GWS01-A20-1432-A11](https://www.mouser.sk/ProductDetail/AAEON-UP/UP-GWS01-A20-1432-A11?qs=sGAEpiMZZMv0NwlthflBi5gjgar2Kmx4s6XR5W%252BBCeg%3D)

kernels does not even have any local console - ssh only

    # jitterdebugger during 16@44 roon playback ; kernel 6.1-rc3-RT2
    # cpu3 = usb
    # cpu1 = eth
    #
    affinity: 0-3 = 4 [0xF]
    T: 0 ( 2300) A: 0 C:     18293 Min:         3 Avg:    5.57 Max:        25
    T: 1 ( 2301) A: 1 C:     18286 Min:         4 Avg:    5.57 Max:        34
    T: 2 ( 2302) A: 2 C:     18278 Min:         4 Avg:    5.63 Max:        14
    T: 3 ( 2303) A: 3 C:     18270 Min:         3 Avg:    4.09 Max:         7
    
Detailed per-cpu core view on jitter:
![jitterplot-outputs-upgw](https://github.com/maniac0r/upboard-audio-tweaks/blob/master/jitterplot-outputs-upgw.png?raw=true)
