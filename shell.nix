{ pkgs ? import <nixpkgs> {} }:
let
    pkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/cf8cc1201be8bc71b7cbbbdaf349b22f4f99c7ae.tar.gz") {};
    
    rustPlatform = pkgs.rust.packages.stable.rustPlatform;

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
    

    #TODO fix this
    rust-surfer = rustPlatform.buildRustPackage rec {
      pname = "surfer";
      version = "0.2.0";

      src = pkgs.fetchgit {
        url = "https://gitlab.com/surfer-project/surfer";
        rev = "v0.2.0";
        hash = "sha256-C5jyWLs7fdEn2oW5BORZYazQwjXNxf8ketYFwlVkHpA=";
      };
        
      cargoHash = "sha256-aDQA4A5mScX9or3Lyiv/5GyAehidnpKKE0grhbP1Ctc=";
      cargoLock = {
        lockFile = "${src}/Cargo.lock";
        outputHashes = {
          "codespan-0.12.0" = "sha256-3F2006BR3hyhxcUTaQiOjzTEuRECKJKjIDyXonS/lrE=";
          "egui_skia-0.5.0" = "sha256-dpkcIMPW+v742Ov18vjycLDwnn1JMsvbX6qdnuKOBC4=";
          "tracing-tree-0.2.0" = "sha256-/JNeAKjAXmKPh0et8958yS7joORDbid9dhFB0VUAhZc=";
        };
      };

      propagatedBuildInputs = [pkgs.rustc pkgs.cargo pkgs.openssl pkgs.pkg-config ];

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
    python311Packages.remote-pdb
    python311Packages.bitstruct

    #Alex Forenchich
    cocotbext-axi
    cocotbext-uart
    cocotbext-i2c

    inetutils
    
    #pkg-config
    #openssl
    #rust-surfer

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
