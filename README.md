# Project Structure

## The environment is managed by nix. Things may be missing from the shell.nix, most notably vivado as I use a separate machine for this. 

## Projects list (For the Alinx AX7325 board)

Currently in active development is eth_10g_pkt_receive.
    
## Directory Structure

    base:
        sourceme    #Sets up environment
        
        vivado:
            RUNME   #Shell script for starting vivado

        scripts:    #Utility directory for storing scripts + others 
            
        design:
            sources/     #All design sources (RTL)
            constraints: #All the constraints for the given sources

        tests:


