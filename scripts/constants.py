import sys

BPSK = 1
QPSK = 2
QAM16 = 4
QAM64 = 6

RATE_6MBPS = 0b1011
RATE_9MBPS = 0b1111
RATE_12MBPS = 0b1010
RATE_18MBPS = 0b1110
RATE_24MBPS = 0b1001
RATE_36MBPS = 0b1101
RATE_48MBPS = 0b1000
RATE_54MBPS = 0b1100

PUNCTURING_1_2 = 6
PUNCTURING_2_3 = 8
PUNCTURING_3_4 = 9

PILOT_WIDTH = 127
PILOT_RESET = 0xe275a0abd218d4cf928b9bbf6cb08f

def puncturing_from_rate(rate: int) -> int:
    """
    This function returns the coding rate associated with a data rate, the coding rate is
    represented using 12 times the puncturing (as a fraction). This way the result can be
    represented as an integer are the possible coding rates are 1/2, 2/3, 3/4
    (represented by 6, 8, 9)

    Source
    ------
    Table 78 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    if rate == RATE_6MBPS: return PUNCTURING_1_2
    if rate == RATE_9MBPS: return PUNCTURING_3_4
    if rate == RATE_12MBPS: return PUNCTURING_1_2
    if rate == RATE_18MBPS: return PUNCTURING_3_4
    if rate == RATE_24MBPS: return PUNCTURING_1_2
    if rate == RATE_36MBPS: return PUNCTURING_3_4
    if rate == RATE_48MBPS: return PUNCTURING_2_3
    if rate == RATE_54MBPS: return PUNCTURING_3_4
    print("invalid data rate: {}".format(rate), file=sys.stderr)
    exit(1)

def modulation_from_rate(rate: int) -> int:
    """
    This function returns the modulation type associated with a data rate, the modulation
    type is represented by the number of bits per symbol (1 for BPSK, 2 for QAM...).

    Source
    ------
    Table 78 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    if rate == RATE_6MBPS: return BPSK
    if rate == RATE_9MBPS: return BPSK
    if rate == RATE_12MBPS: return QPSK
    if rate == RATE_18MBPS: return QPSK
    if rate == RATE_24MBPS: return QAM16
    if rate == RATE_36MBPS: return QAM16
    if rate == RATE_48MBPS: return QAM64
    if rate == RATE_54MBPS: return QAM64
    print("invalid data rate: {}".format(rate), file=sys.stderr)
    exit(1)

def coded_bits_per_subcarier(rate: int) -> int:
    """
    This function returns the number of coded bits per subcarier symbols.

    Source
    ------
    Table 78 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    return modulation_from_rate(rate)

def coded_bits_per_ofdm(rate: int) -> int:
    """
    This function returns the number of coded bits per OFDM symbols.

    Source
    ------
    Table 78 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    return coded_bits_per_subcarier(rate) * 48

def data_bits_per_ofdm(rate: int) -> int:
    """
    This function returns the number of data bits per OFDM symbols.

    Source
    ------
    Table 78 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    return (coded_bits_per_ofdm(rate) * puncturing_from_rate(rate)) // 12

def puncturing_mask(puncturing: int) -> tuple[list[int], list[int]]:
    """
    Returns the puncturing sequence associated with each puncturing type for the outputs
    A and B of the convolutional encoder.

    Source
    ------
    Figure 115 of https://pdos.csail.mit.edu/archive/decouto/papers/802.11a.pdf
    """
    if puncturing == PUNCTURING_1_2:
        return ([1,1,1,1,1,1,1,1], [1,1,1,1,1,1,1,1])
    if puncturing == PUNCTURING_2_3:
        return ([1,1,1,1,1,1], [1,0,1,0,1,0])
    if puncturing == PUNCTURING_3_4:
        return ([1,1,0,1,1,0,1,1,0], [1,0,1,1,0,1,1,0,1])
    print("invalid puncturing fraction: {}".format(puncturing/12), file=sys.stderr)
    exit(1)
