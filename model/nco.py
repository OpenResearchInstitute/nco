#!/usr/bin/env python

from nco import nco

bitrate 	 = 54200
freq_if_mult = 32
sample_rate  = 61.44e6
#sample_rate  = 4.0e6

center_freq = freq_if_mult * bitrate
print(center_freq)
nco = nco.nco(center_freq, sample_rate)

for i in range(10000):
	sc = nco.get_sin_cos()
	print(sc)