import numpy as np

def gen_short_sequence() -> np.ndarray:
    short_sequence = np.zeros((64,), dtype=complex)
    short_sequence[-24] = 1 + 1j
    short_sequence[-20] = -1 + 1j
    short_sequence[-16] = -1 - 1j
    short_sequence[-12] = 1 - 1j
    short_sequence[-8] = -1 - 1j
    short_sequence[-4] = 1 - 1j
    short_sequence[4] = 1 - 1j
    short_sequence[8] = -1 - 1j
    short_sequence[12] = 1 - 1j
    short_sequence[16] = -1 - 1j
    short_sequence[20] = -1 + 1j
    short_sequence[24] = 1 + 1j
    short_sequence *= 1.472
    return short_sequence

def example_time_domain_short_sequence():
    table = np.zeros((64,), dtype=complex)
    table[0]  = 0.046  + 0.046j
    table[1]  = -0.132 + 0.002j
    table[2]  = -0.013  -0.079j
    table[3]  = 0.143  -0.013j
    table[4]  = 0.092  + 0.000j
    table[5]  = 0.143  - 0.013j
    table[6]  = -0.013 - 0.079j
    table[7]  = -0.132 + 0.002j
    table[8]  = 0.046 + 0.046j
    table[9]  = 0.002  -0.132j
    table[10] = -0.079 -0.013j
    table[11] = -0.013 + 0.143j
    table[12] = 0.000 + 0.092j
    table[13] = -0.013 + 0.143j
    table[14] = -0.079  -0.013j
    table[15] = 0.002 - 0.132j
    table[16:32] = table[0:16]
    table[32:48] = table[0:16]
    table[48:64] = table[0:16]
    #print_frequency_domain(scipy.fft.fft(table))
    return table

def gen_long_sequence() -> np.ndarray:
    return np.array([
            0,1,-1,-1,1,1,-1,1,-1,1,-1,-1,-1,-1,-1,1,
            1,-1,-1,1,-1,1,-1,1,1,1,1,0,0,0,0,0,
            0,0,0,0,0,0,1,1,-1,-1,1,1,-1,1,-1,1,
            1,1,1,1,1,-1,-1,1,1,-1,1,-1,1,1,1,1,
        ], dtype=complex)
