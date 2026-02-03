import numpy as np 

class nco():

		def __init__(self, center_freq, sample_freq):
			super(nco, self).__init__()

			self.cf = center_freq
			self.pi = np.uint32(center_freq * 2**32 / sample_freq)
			self.pc = np.uint32(0)

			print("NCO cf: ", center_freq)
			print("NCO pi: ", self.pi)

		def init(self):
			self.pc = np.uint32(0)

		def _phase(self):
			with np.errstate(over='ignore'):
				self.pc = np.uint32(self.pc + self.pi)

		def get_sin_cos(self):

			phase = self.pc
			phase_rad = self.pc * (2.0 * np.pi / 2**32)

			s = np.sin(phase_rad)
			c = np.cos(phase_rad)

			prev_pc = self.pc
			self._phase()
			rollover = 1 if prev_pc > self.pc else 0

			return [s, c, rollover]
