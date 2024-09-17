#!/usr/bin/env python
import sys

input  = float(sys.argv[1])
output = float(sys.argv[2])

def vco_legal(freq):
    return freq >= 800 and freq <= 1600

def factorise(number):
    factors = {2: 0, 5:0}
    i = 2
    while int(number) != number:
        number *= 10
        factors[2] -= 1
        factors[5] -= 1
    number = int(number)
    while True:
        if number % i == 0:
            number = int(number / i)
            if not i in factors:
                factors[i] = 0
            factors[i] += 1
            continue
        i += 1
        if (number == 1):
            return factors 

ratio = factorise(output/input)

def calculate_frequency(input, output):
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
    return {"vco": vco_freq_best,
            "delta": delta,
            "CLKOUT_DIVIDE": settings[0],
            "DIVCLK_DIVIDE": settings[1],
            "CLKFBOUT_MULT": settings[2]}

max_mult   = 65
max_divide = 129 * 57

ratio_mult = {k:ratio[k] for k in ratio if ratio[k] > 0}
ratio_div  = {k:-ratio[k] for k in ratio if ratio[k] < 0}

print("Multiplication factors", ratio_mult)
print("Division       factors", ratio_div)

mult_factors = []
for k in sorted(list(ratio_mult)):
    mult_factors += [k] * ratio_mult[k]

def find_all_combinations(factor, min, max):
    if len(factor) > 20:
        print("Exiting")
        sys.exit(-1)
    for i in range(2 ** len(factor)):
        mult = 1
        for p in range(len(factor)):
            if (i & (2  ** p)) == 1:
                mult *= factor[p] 
        print(mult)

print(find_all_combinations([2, 2, 3], 0, 100))

possible_top_factors = []
out = calculate_frequency(input, output)
