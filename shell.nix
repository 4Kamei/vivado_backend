{ pkgs ? import <nixpkgs> {} }:
let
    pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/cf8cc1201be8bc71b7cbbbdaf349b22f4f99c7ae.tar.gz") {};
in pkgs.mkShell {

  nativeBuildInputs = with pkgs.buildPackages; [	
    zlib

    gtkwave #for viewing vcd/fst

    verilog #icarus verilog
    verilator

    #python
    python311
    python311Packages.cocotb
    python311Packages.pyzmq
    python311Packages.pytest

    cmake
  ];

  shellHook = ''
    echo "Sourcing sourceme"
    source sourceme
  '';

}
