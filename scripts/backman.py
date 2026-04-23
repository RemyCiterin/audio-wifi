import numpy as np

def backman(x, N):
    if N == 0: return x
    alpha = 0.16
    i = np.arange(N+1)
    a0 = (1 - alpha) / 2
    a1 = 1 / 2
    a2 = alpha / 2
    w = a0 - a1 * np.cos(2*np.pi*i/N) + a2 * np.cos(4*np.pi*i/N)
    return np.convolve(x, w) / np.sum(w)
