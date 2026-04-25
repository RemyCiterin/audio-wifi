import matplotlib.pyplot as plt
import sounddevice as sd
import numpy as np
import argparse
import scipy
import math
import wave
import sys

import constants
from convolutive_encoder import ViterbiDecoder, ConvEncoder
from scrambler import Scrambler, DeScrambler

from header import makeheader, from_header
from interleaver import Interleaver, DeInterleaver
from mapper import Mapper, DeMapper, make_constelation
from training import gen_long_sequence, gen_short_sequence
from encoder import Encoder
from equalisation import ChannelEqualisation

def print_frequency_domain(mapped: np.ndarray):
    num_spaces = 0
    fmt = []

    for m in mapped:
        fmt.append("{:.2}".format(m))
        num_spaces = max(num_spaces, len(fmt[-1]))

    for i in range(32):
        j = i-32
        print(end="out[{:2}] =   {}".format(j, fmt[j]))
        for _ in range(3+num_spaces-len(fmt[j])): print(end=" ")
        print("out[{:2}] =   {}".format(i, fmt[i]))

def print_time_domain(map: np.ndarray):
    num_spaces = 0
    fmt = []

    for m in map:
        fmt.append("{:.2}".format(m))
        num_spaces = max(num_spaces, len(fmt[-1]))

    N = len(map) // 2
    for i in range(N):
        print(end="out[{:2}] =   {}".format(i, fmt[i]))
        for _ in range(3+num_spaces-len(fmt[i])): print(end=" ")
        print("out[{:2}] =   {}".format(i+N, fmt[i+N]))

def format_bits(bits: list[int]) -> str:
    """
        Given a bitstream represented as a list of integers in the set {0,1}, returns a
        string made of zeros and ones
    """
    s = ""
    for b in bits:
        if b == 1: s += "1"
        else: s += "0"
    return s



class PacketDetector:
    def __init__(self):
        self.buf1 = np.zeros((2 * 81 - 16))
        self.buf2 = np.zeros((2 * 81 - 16))
        self.buf3 = np.zeros((2 * 81 - 16))

parser = argparse.ArgumentParser()
parser.add_argument("--encode", action= "store_true")
parser.add_argument("--decode", action= "store_true")

args = vars(parser.parse_args(sys.argv[1:]))

Nrepeat = 250
sample_rate = 44100
carrier_freq = 2000
BACKMAN_SIZE = Nrepeat

if __name__ == "__main__" and args["encode"]:
    print("== Encoder properties ==")
    print("sample rate: {}".format(sample_rate))
    print("center carrier frequency: {}Hz".format(carrier_freq))
    print("sub-carrier spacing: {}Hz".format(44100 / Nrepeat))

    sys.stdout.flush()

    message = [
            0x04, 0x02, 0x00, 0x2e, 0x00,
            0x60, 0x08, 0xcd, 0x37, 0xa6,
            0x00, 0x20, 0xd6, 0x01, 0x3c,
            0xf1, 0x00, 0x60, 0x08, 0xad,
            0x3b, 0xaf, 0x00, 0x00, 0x4a,
            0x6f, 0x79, 0x2c, 0x20, 0x62,
            0x72, 0x69, 0x67, 0x68, 0x74,
            0x20, 0x73, 0x70, 0x61, 0x72,
            0x6b, 0x20, 0x6f, 0x66, 0x20,
            0x64, 0x69, 0x76, 0x69, 0x6e,
            0x69, 0x74, 0x79, 0x2c, 0x0a,
            0x44, 0x61, 0x75, 0x67, 0x68,
            0x74, 0x65, 0x72, 0x20, 0x6f,
            0x66, 0x20, 0x45, 0x6c, 0x79,
            0x73, 0x69, 0x75, 0x6d, 0x2c,
            0x0a, 0x46, 0x69, 0x72, 0x65,
            0x2d, 0x69, 0x6e, 0x73, 0x69,
            0x72, 0x65, 0x64, 0x20, 0x77,
            0x65, 0x20, 0x74, 0x72, 0x65,
            0x61, 0xda, 0x57, 0x99, 0xed
        ]

    encoder = Encoder()
    encoded_samples = encoder.run(constants.RATE_24MBPS, message)

    samples = []
    for x in encoded_samples:
        for _ in range(Nrepeat): samples.append(x)
    samples = np.array(samples)

    from backman import backman
    samples = backman(samples, BACKMAN_SIZE)

    carrier_cos = np.cos(2*np.pi*carrier_freq*np.arange(len(samples))/sample_rate)
    carrier_sin = np.sin(2*np.pi*carrier_freq*np.arange(len(samples))/sample_rate)
    I = samples.real * 10
    Q = samples.imag * 10

    signal = I * carrier_cos + Q * carrier_sin

    sd.play(signal, sample_rate, blocking=True)
    samples = np.concatenate((np.zeros(100000), signal, np.zeros(100000)))
    samples += 0.1 * np.random.randn(len(samples))
    samples = np.round(samples*2)

if __name__ == "__main__" and args["decode"]:

    print("== Decoder properties ==")
    print("sample rate: {}".format(sample_rate))
    print("center carrier frequency: {}Hz".format(carrier_freq))
    print("sub-carrier spacing: {}Hz".format(44100 / Nrepeat))

    equalisation = ChannelEqualisation()

    file = wave.open("recorded.wav", mode="rb")
    num_frames = file.getnframes()
    sample_rate = file.getframerate()
    samples = file.readframes(num_frames)
    samples = np.frombuffer(samples, dtype=np.int16)
    samples = samples.astype(float)

    #carrier_freq += 0.1
    samples = samples - samples.mean()
    samples = samples / np.sqrt(np.mean(samples**2))

    print(np.mean(np.abs(samples)))
    #file = open("samples.hex", "w")
    #print("@0", file=file)
    #for sample in samples:
    #    sample = int(sample * 65536)
    #    if sample < 0:
    #        sample = sample + 65536 * 65536
    #    print("{:08x}".format(sample), file=file)
    #file.close()

    plt.plot(
            np.arange(len(samples) // 2) * 44100 / len(samples),
            10*np.log10(np.abs(scipy.fft.rfft(samples)[:len(samples)//2])))
    plt.show()

    carrier_cos = np.cos(2*np.pi*carrier_freq*np.arange(len(samples))/sample_rate)
    carrier_sin = np.sin(2*np.pi*carrier_freq*np.arange(len(samples))/sample_rate)
    carrier_cos = 2.0 * (carrier_cos > 0) - 1
    carrier_sin = 2.0 * (carrier_sin > 0) - 1

    from backman import backman
    I = samples * carrier_cos
    Q = samples * carrier_sin

    acc_I = 0
    acc_Q = 0
    for i in range(len(I)):
        new_I = acc_I
        new_Q = acc_Q
        acc_I = (1-0.005) * acc_I + 0.005 * I[i]
        acc_Q = (1-0.005) * acc_Q + 0.005 * Q[i]
        I[i] = new_I # acc_I
        Q[i] = new_Q # acc_Q

    #I = backman(I, BACKMAN_SIZE)
    #Q = backman(Q, BACKMAN_SIZE)
    X = I + 1j*Q

    plt.plot(I*I+Q*Q)
    plt.show()

    print(len(X))
    factor = Nrepeat
    I = I[::factor]
    Q = Q[::factor]
    X = X[::factor]
    sample_rate //= factor
    Nrepeat //= factor
    Ts = 81
    Tp = 16

    for (i, s) in enumerate(I):
        print("samples[{}] = {:.4f}".format(i, s))

    def C1(t):
        Xt = X[t:t+Nrepeat*(2*Ts-Tp)].conjugate()
        Xt_ = X[t+Nrepeat*Tp:t+Nrepeat*2*Ts]
        return (Xt * Xt_).sum()

    def P1(t):
        return 44100
        #Xt = X[t:t+Nrepeat*(2*Ts-Tp)]
        #return np.sum(Xt * Xt.conjugate()).real

    print(len(I))
    C1_array = np.zeros((len(I) // Nrepeat - 2*Ts), dtype=complex)

    for i in range(len(C1_array)):
        C1_array[i] = C1(i*Nrepeat) / P1(i*Nrepeat)

    C1_argmax = np.argmax(np.abs(C1_array)) * Nrepeat

    plt.plot(np.arange(len(C1_array)) / Nrepeat, C1_array.real)
    plt.plot(np.arange(len(C1_array)) / Nrepeat, C1_array.imag)
    plt.show()

    # Find the frequency offset
    freq_offset1 =  \
        np.angle(C1_array[C1_argmax // Nrepeat]) * sample_rate / (2*np.pi * Nrepeat * Tp)

    print("frequency offset: {}, new frequency: {}"
          .format(freq_offset1, carrier_freq + freq_offset1))

    #X *= np.exp(-2j*np.pi*freq_offset1/sample_rate*np.arange(len(I)))
    I = X.real
    Q = X.imag

    start_ltf1 = (2 * Ts + Tp) * Nrepeat + C1_argmax

    scores = []
    tested = list(range(-30*Nrepeat, 30*Nrepeat))
    expected = scipy.fft.ifft(gen_long_sequence())

    print()
    for i in range(64):
        print("cmplx({:.5}, {:.5}), ".format(expected.real[i], expected.imag[i]),
              end="" if i % 2 == 0 else "\n")

    for i in tested:
        start_i = start_ltf1 + i
        x = X[start_i:start_i+64*Nrepeat:Nrepeat]
        score = np.abs(np.sum(x * expected.conjugate())) ** 2
        scores.append(score)

    plt.plot(np.array(tested) / Nrepeat, scores)
    plt.show()

    start_ltf1 += tested[np.argmax(scores)]
    print("start ltf1", start_ltf1)

    start_ltf2 = start_ltf1 + Nrepeat * Ts
    ltf1 = X[start_ltf1:start_ltf1+Nrepeat*64:Nrepeat]
    ltf2 = X[start_ltf2:start_ltf2+Nrepeat*64:Nrepeat]
    print("ltf1: ")
    print_time_domain(ltf1)
    print("ltf2: ")
    print_time_domain(ltf2)
    equalisation.set_ltf((ltf2 + ltf1) / 2)

    header_pos = start_ltf1 + 2 * Ts * Nrepeat
    header = X[header_pos:header_pos+Nrepeat*64:Nrepeat]
    header_freq = equalisation.run(True, scipy.fft.fft(header))
    print_frequency_domain(header_freq)

    plt.plot(header_freq.real, header_freq.imag, ".")
    plt.xlim([-4, 4])
    plt.ylim([-4, 4])
    plt.show()

    demapper = DeMapper()
    deinterleaver = DeInterleaver()
    viterbi = ViterbiDecoder()
    descrambler = DeScrambler()

    header = demapper.run(constants.RATE_6MBPS, header_freq)
    header = deinterleaver.run(constants.RATE_6MBPS, header)
    header = viterbi.run(constants.RATE_6MBPS, header)
    (length, rate) = from_header(header)
    print("length: {} rate: {:b}".format(length, rate))
    print(format_bits(header))

    CONSTELATION_36M = make_constelation(rate)
    plt.plot(CONSTELATION_36M.real, CONSTELATION_36M.imag, "ko", markersize=10)

    print((length * 8 + 24) / constants.data_bits_per_ofdm(rate))
    for i in range(math.ceil((length * 8 + 24) / constants.data_bits_per_ofdm(rate)) - 1):
        print("\n===== receive symbol {} =====".format(i))

        data_pos = start_ltf1 + (3+i) * Ts * Nrepeat
        data = X[data_pos:data_pos+Nrepeat*64:Nrepeat]
        if len(data) < 64: break

        data_freq = equalisation.run(False, scipy.fft.fft(data))
        data = demapper.run(rate, data_freq)
        data = deinterleaver.run(rate, data)

        if constants.puncturing_from_rate(rate) == constants.PUNCTURING_1_2: batch_size = 48
        if constants.puncturing_from_rate(rate) == constants.PUNCTURING_2_3: batch_size = 36
        if constants.puncturing_from_rate(rate) == constants.PUNCTURING_3_4: batch_size = 32

        for j in range(len(data) // batch_size):
            x = data[j*batch_size:(j+1)*batch_size]
            x = viterbi.run(rate if i == 0 and j == 0 else None, x)
            x = descrambler.run(i == 0 and j == 0, x)
            print(format_bits(x))

            for k in range(3):
                byte = 0
                for i in range(8):
                    byte |= x[8*k+i] << i
                print(chr(byte), end="")
            print()

        if i == 0: color = "r."
        elif i == 1: color = "r."
        elif i == 2: color = "b."
        else: color = "b."
        plt.plot(data_freq.real, data_freq.imag, color)

    plt.xlim([-4, 4])
    plt.ylim([-4, 4])
    plt.show()

    circle = np.exp(2j * np.pi * np.arange(64) / 64)
    for i in range(64):
        if i % 2 == 0: print()
        print(end="cmplx({}, {}),".format(circle.real[i], circle.imag[i]))
