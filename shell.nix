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

    #Alex Forenchich
    cocotbext-axi
    cocotbext-uart

    cmake
  ];

  shellHook = ''
    echo "Sourcing sourceme"
    source sourceme
  '';

}
