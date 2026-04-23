from training import gen_long_sequence
import numpy as np
import constants
import scipy

class ChannelEqualisation:
    """
    Perform channel estimation, equalisation and remaining phase correction. This module
    is in charge of using the estimation of the channel given by the analysis of the
    long training sequence to compensate the distortions of the communication channel.
    It also use the pilot frequencies to detect and compensate (uniform) phase errors
    in the equalised frequencies.
    """
    def __init__(self):
        self.correction = np.ones((64,), dtype=complex)
        self.pilot = constants.PILOT_RESET
        pass

    def set_ltf(self, ltf: np.ndarray):
        """
        Use the long training symbol as an estimation of the channel distortions
        """
        self.correction = gen_long_sequence() / scipy.fft.fft(ltf)

    def run(self, reset: bool, fft: np.ndarray):
        """
        Run the equalisation process on a symbol represented in the frequency domain
        """
        if reset:
            self.pilot = constants.PILOT_RESET

        fft *= self.correction

        pilot_sign = 1.0 if self.pilot & 1 == 1 else -1
        fft[7] *= pilot_sign
        fft[21] *= -pilot_sign
        fft[-7] *= pilot_sign
        fft[-21] *= pilot_sign

        # rotate the pilot sequence by one step
        self.pilot = (self.pilot >> 1) + ((self.pilot & 1) << (constants.PILOT_WIDTH-1))

        angle = np.angle(fft[7] + fft[21] + fft[-7] + fft[-21])
        fft *= np.exp(-1j*angle)

        return fft
