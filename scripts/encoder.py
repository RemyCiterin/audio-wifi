import numpy as np
import scipy

import constants
from convolutive_encoder import ConvEncoder
from scrambler import Scrambler

from header import makeheader
from interleaver import Interleaver
from training import gen_long_sequence, gen_short_sequence
from mapper import Mapper

def to_time_domain(freq_domain: np.ndarray) -> np.ndarray:
    out = scipy.fft.ifft(freq_domain)
    # cyclic encoding of the IFFT
    out = np.concatenate(
            (out[-16:], out, out[0:1]))
    # windowing function
    out[-1] *= 0.5
    out[0] *= 0.5
    return out

class Encoder:
    def __init__(self):
        self.scrambler = Scrambler()
        self.conv_encoder = ConvEncoder()
        self.interleaver = Interleaver()
        self.mapper = Mapper()

    def compute_data_field(self, rate, message) -> list[int]:
        # SERVICE field
        data = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]

        # PSDU field (message data)
        for m in message:
            for k in range(8):
                data.append(m >> k & 1)

        # Run the scrambler, we don't run it on the rest of the data, because we need them to be
        # zeroed before calling the convolutional encoder
        data = self.scrambler.run(True, data)

        # TAIL field
        data += [0,0,0,0,0,0]

        # ZERO PADDING
        Ndbps = constants.data_bits_per_ofdm(rate)
        if len(data) % Ndbps != 0:
            for i in range(Ndbps - (len(data) % Ndbps)):
                data.append(0)

        return data

    def run(self, rate: int, message):
        samples = np.zeros(0, dtype=complex)

        frequencies_stf = gen_short_sequence()
        frequencies_ltf = gen_long_sequence()
        samples = np.concatenate((samples, to_time_domain(frequencies_stf)))
        samples = np.concatenate((samples, to_time_domain(frequencies_stf)))
        samples = np.concatenate((samples, to_time_domain(frequencies_ltf)))
        samples = np.concatenate((samples, to_time_domain(frequencies_ltf)))

        ############################################################################
        # Encode the header (SIGNAL field)
        ############################################################################
        self.interleaver.reset(constants.RATE_6MBPS)
        header = makeheader(len(message), rate)
        encoded_header = self.conv_encoder.run(constants.RATE_6MBPS, header)
        interleaved_header = self.interleaver.run(encoded_header)
        frequencies_header = self.mapper.run(True, constants.RATE_6MBPS, interleaved_header)
        samples = np.concatenate((samples, to_time_domain(frequencies_header)))


        ############################################################################
        # Encode the DATA field (SERVICE + PSDU + TAIL + PADDING)
        ############################################################################
        self.interleaver.reset(rate)
        self.scrambler.reset = [1,0,1,1,1,0,1]
        data = self.compute_data_field(rate, message)

        # We process the data by packet of 24 bits
        for i in range(len(data) // 24):
            scrambled_bits = data[i*24:(i+1)*24]
            #scrambled_bits = self.scrambler.run(i == 0, bits)
            encoded_bits = self.conv_encoder.run(rate if i == 0 else None, scrambled_bits)

            interleaved_bits = self.interleaver.run(encoded_bits)
            if len(interleaved_bits) == 0: continue

            frequencies_bits = self.mapper.run(False, rate, interleaved_bits)
            samples = np.concatenate((samples, to_time_domain(frequencies_bits)))

        return samples
