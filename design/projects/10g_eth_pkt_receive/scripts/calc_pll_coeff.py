#!/usr/bin/env python
import sys

input  = float(sys.argv[1])
output = float(sys.argv[2])

stages = int(sys.argv[3]) 

def vco_legal(freq):
    return freq >= 800 and freq <= 1600

print("F_OUT = F_IN * M / (D * O)")

delta = None
best_output = None
settings = []
vco_freq_best = 0

for CLKOUT_DIVIDE in range(1, 129):
    for DIVCLK_DIVIDE in range(1, 57):
        for CLKFBOUT_MULT in range(2, 65):
            vco_freq = float(input * CLKFBOUT_MULT / DIVCLK_DIVIDE)
            output_freq = vco_freq / (CLKOUT_DIVIDE)
            delta_l = abs(output_freq - output)
            if vco_legal(vco_freq) and (delta == None or delta_l <= delta):
                if vco_freq > vco_freq_best or delta_l < delta:
                    settings = [CLKOUT_DIVIDE, DIVCLK_DIVIDE, CLKFBOUT_MULT]
                    delta = delta_l
                    best_output = output_freq
                    vco_freq_best = vco_freq    


print(f"CLOSEST FREQ  = {best_output}")
print(f"DELTA         = {delta}")
print()
print(f"VCO FREQUENCY = {vco_freq_best}")
print()
print(f"CLKOUT_DIVIDE = {settings[0]}")
print(f"DIVCLK_DIVIDE = {settings[1]}")
print(f"CLKFBOUT_MULT = {settings[2]}")
