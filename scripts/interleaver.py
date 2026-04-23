import numpy as np
import constants

def interleave_sequence(rate: int) -> list[int]:
    """
    This function generate the interleaving sequence of the encoder depending of the data
    rate. The sequence is returned as a generator where the i-th output give the
    interleaved position of the i-th bit.

    Source
    ------
        Section 17.3.5.6 https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    Nbpsc = constants.coded_bits_per_subcarier(rate)
    Ncbps = constants.coded_bits_per_ofdm(rate)
    for k in range(Ncbps):
        s = max(Nbpsc//2, 1)
        i = (Ncbps//16) * (k%16) + (k//16)
        j = s * (i//s) + ((i+Ncbps - ((16*i)//Ncbps)) % s)
        yield j

class DeInterleaver:
    def __init__(self):
        pass

    def run(self, rate: int, data: list[int]):
        out = []
        for i in interleave_sequence(rate):
            out.append(data[i])

        return out

class Interleaver:
    """
    The interleaver is in charge of combining data into batches usin an intermediate
    buffer, then flush this buffer using the correct interleaving sequence.
    """
    def __init__(self):
        self.buffer = np.zeros((288,))
        self.sequence = None
        self.rate = None
        self.index = 0
        self.bits = 0

    def reset(self, rate: int):
        """
        Reset the interleaver using a given rate. This operation must be performed each
        times we start encoding a new header or data field.
        """
        self.sequence = list(interleave_sequence(rate))
        self.buffer = np.zeros((288,))
        self.rate = rate
        self.index = 0

    def flush(self):
        """
        Flush the interleaver at the end of a packet, this is equivalent to add zeros to
        align the packet size with the data_bits_per_ofdm(rate)
        """
        out = np.zeros(len(self.sequence))

        for i in range(len(self.sequence)):
            out[self.sequence[i]] = self.buffer[i]

        return out


    def run(self, data) -> list[int]:
        for i in range(len(data)):
            self.buffer[self.index] = data[i]
            self.index += 1

        out = []
        if self.index == len(self.sequence):
            out = self.flush()

            self.reset(self.rate)

        return out
