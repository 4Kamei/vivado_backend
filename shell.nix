{ pkgs ? import <nixpkgs> {} }:
let
    pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/cf8cc1201be8bc71b7cbbbdaf349b22f4f99c7ae.tar.gz") {};
    
    cocotbext-axi = with pkgs.python3Packages; buildPythonPackage rec {
      name = "cocotbext-axi";
      version = "master";

      src = pkgs.fetchgit {
        url = "https://github.com/alexforencich/cocotbext-axi";
        rev = "v0.1.24";  
        hash = "sha256-/OBFezpsmWQyCPuYs/3Yan9v9GrQ5wvEw4PU6pLugkI=";
      };

      propagatedBuildInputs = [ pip cocotb cocotb-bus ];
    };
    
    cocotbext-uart = with pkgs.python3Packages; buildPythonPackage rec {
      name = "cocotbext-uart";
      version = "master";

      src = pkgs.fetchgit {
        url = "https://github.com/alexforencich/cocotbext-uart";
        rev = "v0.1.2";  
        hash = "sha256-WrS2cizxcGEAI2tXiE5ay9/HQx3ANoEn6NfF8rBQ+NI=";
      };

      propagatedBuildInputs = [ pip cocotb cocotb-bus ];
    };

    cocotbext-i2c = with pkgs.python3Packages; buildPythonPackage rec {
      name = "cocotbext-i2c";
      version = "master";

      src = pkgs.fetchgit {
        url = "https://github.com/GiuseppeDiGuglielmo/cocotbext-i2c";
        rev = "9d30c33cef06cec840a80527030077d36ef93dc8";  
        hash = "sha256-mIS72jejO+gqdNFaD7QFCXDtwxgQlpdHiJbVfYsvArc";
      };

      propagatedBuildInputs = [ pip cocotb cocotb-bus ];
    };

in pkgs.mkShell {

  nativeBuildInputs = with pkgs.buildPackages; [	
    zlib
  
    gtkwave #for viewing vcd/fst

    verilog #icarus verilog
    verilator

    #python
    python311
    python311Packages.cocotb
    python311Packages.cocotb-bus
    python311Packages.pyzmq
    python311Packages.pytest
    python311Packages.pyserial
    python311Packages.json5
    python311Packages.jsonschema
    python311Packages.scapy
    #Alex Forenchich
    cocotbext-axi
    cocotbext-uart
    cocotbext-i2c

    #For converting wavedrom files into ascii
    #asciiwave

    cmake
  ];

  shellHook = ''
    echo "Sourcing sourceme"
    source sourceme
    export PATH="$(pwd)/bin/:$PATH"
    export PYTHONPATH="$(pwd)/cocotb/utils:$PYTHONPATH"
    '';

}
