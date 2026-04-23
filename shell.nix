{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    # RTL simulation
    pkgs.bluespec
    pkgs.verilator
    pkgs.verilog
    pkgs.gtkwave

    # Some tools for FPGA implementation
    pkgs.yosys
    pkgs.nextpnr
    pkgs.trellis
    pkgs.icestorm
    pkgs.python313Packages.apycula
    pkgs.openfpgaloader

    # View dot files
    pkgs.xdot

    pkgs.python313Packages.numpy
    pkgs.python313Packages.scipy
    pkgs.python313Packages.matplotlib
    pkgs.python313Packages.sounddevice
    pkgs.python313Packages.wavefile
    pkgs.SDL2
    pkgs.sox

    pkgs.ffmpeg-full
    pkgs.alsa-utils
  ];

  shellHook = ''
    export BLUESPECDIR=${pkgs.bluespec}/lib
    '';
}
