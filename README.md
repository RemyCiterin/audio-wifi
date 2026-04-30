# Presentation

This project is a toy implementation of a 802.11a decoder in Bluespec System Verilog (BSV) adapted
to work with audio samples instead of RF (mostly for fun).

# Features

- Multiple choice of FFT implementations, the one by default is a radix-2 SDF-FFT.
- Support of many data rates: 6, 12, 18, 24, 36, 48, 54Mb/s. Only 9Mb/s is not supported
    because it require to split packets of 24-bits in multiple OFDM symbols but this one is otional
    in the specification.

# TODO

- synchronisation: add carrier frequency offset estimation and correction: I don't known if the
    pilot based phase correction in Equalisation.bsv is enough.
- improve viterbi decoder: decode with a constant delay, or decode the full message at once. It's
    also possible to use soft-decisions from the demapper to improve the accuracy.
