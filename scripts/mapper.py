import numpy as np
import constants
import math
import sys

def make_constelation(rate: int) -> np.ndarray:
    if constants.modulation_from_rate(rate) == constants.BPSK:
        constelation = np.zeros((2,), dtype=complex)
        for i in range(2):
            I = 1 if i >> 0 & 1 == 1 else -1
            constelation[i] = I

    if constants.modulation_from_rate(rate) == constants.QPSK:
        constelation = np.zeros((4,), dtype=complex)
        for i in range(4):
            I = 1 if i >> 0 & 1 == 1 else -1
            Q = 1 if i >> 1 & 1 == 1 else -1
            constelation[i] = (I + 1j * Q) / math.sqrt(2)

    if constants.modulation_from_rate(rate) == constants.QAM16:
        constelation = np.zeros((16,), dtype=complex)

        for i in range(16):
            if i >> 0 & 1 == 0 and i >> 1 & 1 == 0: I = -3
            if i >> 0 & 1 == 0 and i >> 1 & 1 == 1: I = -1
            if i >> 0 & 1 == 1 and i >> 1 & 1 == 1: I = 1
            if i >> 0 & 1 == 1 and i >> 1 & 1 == 0: I = 3

            if i >> 2 & 1 == 0 and i >> 3 & 1 == 0: Q = -3
            if i >> 2 & 1 == 0 and i >> 3 & 1 == 1: Q = -1
            if i >> 2 & 1 == 1 and i >> 3 & 1 == 1: Q = 1
            if i >> 2 & 1 == 1 and i >> 3 & 1 == 0: Q = 3
            constelation[i] = (I + 1j * Q) / math.sqrt(10)

    if constants.modulation_from_rate(rate) == constants.QAM64:
        print("64-QAM is not implemented yet", file= sys.stderr)
        exit(1)

    return constelation

class DeMapper:
    def __init__(self):
        self.pilot = constants.PILOT_RESET
        self.positions = \
                [-26,-25,-24,-23,-22,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,\
                -8,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19,20,\
                22,23,24,25,26]

    def run(self, rate: int, data: np.ndarray) -> list[int]:
        out = []

        for i in range(48):
            symbol = data[self.positions[i]]
            constelation = make_constelation(rate)

            imin = int(np.argmin( np.abs(symbol - constelation) ))

            for i in range(constants.coded_bits_per_subcarier(rate)):
                out.append(imin >> i & 1)

        return out

class Mapper:
    """
    The mapper is in charge of mapping data from the bitstream given by the interleaver
    into a stream of OFDM symbols in the frequency domain, at every call it take a batch
    of `coded_bits_per_ofdm(rate)` bits and encode those bits into an array of 64 complex
    numbers representing the I/Q coordinates of each subcarrier.

    Attributes
    ----------
        pilot:
            127-bits shift register used to generate the I/Q coordinates of the pilots
            subcarriers
        positions:
            positions of each of the 48 generated symbols into the 64 available subcarriers
    """
    def __init__(self):
        self.pilot = constants.PILOT_RESET
        self.positions = \
                [-26,-25,-24,-23,-22,-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-9,\
                -8,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,8,9,10,11,12,13,14,15,16,17,18,19,20,\
                22,23,24,25,26]

    def run(self, reset: bool, rate: int, data: list[int]) -> np.ndarray:
        """
        Given a list of `coded_bits_per_ofdm(rate)` bits, perform the mapping of the
        symbols to the 64 carriers taken as input of the IFFT module.
        """
        assert(len(data) == constants.coded_bits_per_ofdm(rate))

        if reset:
            self.pilot = constants.PILOT_RESET

        out = np.zeros((64,), dtype=complex)

        # insert the pilots
        pilot_sign = 1.0 if self.pilot & 1 == 1 else -1
        out[7] = pilot_sign
        out[21] = -pilot_sign
        out[-7] = pilot_sign
        out[-21] = pilot_sign

        # rotate the pilot sequence by one step
        self.pilot = (self.pilot >> 1) + ((self.pilot & 1) << (constants.PILOT_WIDTH-1))

        for i in range(48):
            I = 0
            Q = 0

            if constants.modulation_from_rate(rate) == constants.BPSK:
                I = 1 if data[i] == 1 else -1

            if constants.modulation_from_rate(rate) == constants.QPSK:
                I = 1 if data[i*2] == 1 else -1
                Q = 1 if data[i*2+1] == 1 else -1

                I /= math.sqrt(2)
                Q /= math.sqrt(2)

            if constants.modulation_from_rate(rate) == constants.QAM16:
                if data[4*i] == 0 and data[4*i+1] == 0: I = -3
                if data[4*i] == 0 and data[4*i+1] == 1: I = -1
                if data[4*i] == 1 and data[4*i+1] == 1: I = 1
                if data[4*i] == 1 and data[4*i+1] == 0: I = 3

                if data[4*i+2] == 0 and data[4*i+3] == 0: Q = -3
                if data[4*i+2] == 0 and data[4*i+3] == 1: Q = -1
                if data[4*i+2] == 1 and data[4*i+3] == 1: Q = 1
                if data[4*i+2] == 1 and data[4*i+3] == 0: Q = 3

                I /= math.sqrt(10)
                Q /= math.sqrt(10)

            if constants.modulation_from_rate(rate) == constants.QAM64:
                print("64-QAM is not implemented yet", file= sys.stderr)
                exit(1)

            out[self.positions[i]] = I + 1j * Q
        return out
