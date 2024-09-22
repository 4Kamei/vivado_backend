import sys

mif = sys.argv[1]

with open(mif, "r") as f:
    for line in f:
        line = line.replace("\n", "")
        addr = line[0:8]
        data = line[8:16]
        mask = line[16:24]
        
        if (mask == "00000000"):
            continue
        addr = int(addr, 2)
        data = int(data, 2)
        
        print(f"{addr}, {data}, {mask}")

        

