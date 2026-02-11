"""
Python model of nco.vhd + sin_cos_lut.vhd — Numerically Controlled Oscillator.

RTL architecture (NO_DSP_GEN path):
  - phase_sum = phase_acc + phase_delta_adjusted
  - On enable:
    - Latch freq_adjust on freq_adj_valid, clear on freq_adj_zero
    - phase_delta_adjusted = freq_word + freq_adjust_q (signed addition)
    - phase_acc = phase_sum
    - Quadrant rollover detection from MSBs transition
    - tclk_even on pi/2 and 3pi/2 rollovers, tclk_odd on 2pi and pi rollovers
    - discard_nco: decimation counter - only update phase output when count==0

  sin_cos_lut:
    - Direct ROM lookup, 1024 entries (PHASE_W=10)
    - LUT values = round(sin/cos(i * 2*pi/1024) * 1024)
    - Output is signed SINUSOID_W bits
"""

import sys
import os
import math
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))
from model_utils import signed, unsigned

import numpy as np


class Nco:
    def __init__(self, nco_w=32, phase_w=10, sinusoid_w=12,
                 phase_init=0, fixed_point=False):
        self.NCO_W = nco_w
        self.PHASE_W = phase_w
        self.SINUSOID_W = sinusoid_w
        self.PHASE_INIT = unsigned(phase_init, nco_w)
        self.fixed_point = fixed_point

        # Build sin/cos LUT (matches RTL exactly)
        self.PHASES = 1 << phase_w
        self._build_lut()

        self.reset()

    def _build_lut(self):
        """Build LUT matching sin_cos_lut.vhd fill_sincos_lut function."""
        unit_period = 2.0 * math.pi / 1024.0
        self.sin_lut = []
        self.cos_lut = []
        for i in range(self.PHASES):
            theta = i * unit_period
            s = int(round(math.sin(theta) * 1024.0))
            c = int(round(math.cos(theta) * 1024.0))
            self.sin_lut.append(signed(s, self.SINUSOID_W))
            self.cos_lut.append(signed(c, self.SINUSOID_W))

    def reset(self):
        NW = self.NCO_W
        if self.fixed_point:
            self.phase_acc = self.PHASE_INIT
            self.phase_delta_adjusted = self.PHASE_INIT
            # Compute PHASE_MSBS_INIT: resize(shift_right(PHASE_INIT-1, 30), 2)
            init_minus1 = unsigned(self.PHASE_INIT - 1, NW)
            self.phase_acc_msbs = (init_minus1 >> (NW - 2)) & 0x3
            self.freq_adjust_q = 0
            self.discard_count = 0
            self._phase = 0
            self._rollover_pi2 = 0
            self._rollover_pi = 0
            self._rollover_3pi2 = 0
            self._rollover_2pi = 1  # RTL inits rollover_2pi to '1'
            self._tclk_even = 0
            self._tclk_odd = 0
            self._sin = 0
            self._cos = 0
        else:
            self.phase_acc = 0.0  # 0..1 representing 0..2pi
            self._phase = 0.0
            self._sin = 0.0
            self._cos = 0.0
            self._rollover_pi2 = 0
            self._rollover_pi = 0
            self._rollover_3pi2 = 0
            self._rollover_2pi = 0
            self._tclk_even = 0
            self._tclk_odd = 0
            self._prev_quadrant = 0

    def step(self, enable, freq_word, freq_adjust=0, freq_adj_valid=0,
             freq_adj_zero=0, discard_nco=0):
        """One clock cycle. Returns dict of outputs."""
        if not self.fixed_point:
            return self._step_float(enable, freq_word)
        else:
            return self._step_fixed(enable, freq_word, freq_adjust,
                                    freq_adj_valid, freq_adj_zero, discard_nco)

    def _step_float(self, enable, freq_word):
        """Floating-point mode. freq_word is fraction of full-scale per sample."""
        if enable:
            prev_quad = int(self.phase_acc * 4) % 4
            self.phase_acc = (self.phase_acc + freq_word) % 1.0
            new_quad = int(self.phase_acc * 4) % 4

            self._rollover_pi2 = 1 if prev_quad == 0 and new_quad == 1 else 0
            self._rollover_pi = 1 if prev_quad == 1 and new_quad == 2 else 0
            self._rollover_3pi2 = 1 if prev_quad == 2 and new_quad == 3 else 0
            self._rollover_2pi = 1 if prev_quad == 3 and new_quad == 0 else 0

            self._tclk_even = self._rollover_pi2 or self._rollover_3pi2
            self._tclk_odd = self._rollover_2pi or self._rollover_pi

            theta = self.phase_acc * 2.0 * np.pi
            self._sin = np.sin(theta)
            self._cos = np.cos(theta)
            self._phase = self.phase_acc

        return {
            'phase': self._phase,
            'sin': self._sin,
            'cos': self._cos,
            'rollover_pi2': self._rollover_pi2,
            'rollover_pi': self._rollover_pi,
            'rollover_3pi2': self._rollover_3pi2,
            'rollover_2pi': self._rollover_2pi,
            'tclk_even': self._tclk_even,
            'tclk_odd': self._tclk_odd,
        }

    def _step_fixed(self, enable, freq_word, freq_adjust,
                    freq_adj_valid, freq_adj_zero, discard_nco):
        NW = self.NCO_W
        PW = self.PHASE_W
        SW = self.SINUSOID_W
        MASK = (1 << NW) - 1

        if enable:
            # Latch frequency adjustment
            if freq_adj_valid:
                self.freq_adjust_q = freq_adjust
            if freq_adj_zero:
                self.freq_adjust_q = 0

            # phase_delta_adjusted = freq_word + freq_adjust_q (signed add, unsigned result)
            self.phase_delta_adjusted = unsigned(
                signed(freq_word, NW) + signed(self.freq_adjust_q, NW), NW
            )

            # phase_sum = phase_acc + phase_delta_adjusted
            phase_sum = unsigned(self.phase_acc + self.phase_delta_adjusted, NW)

            # Update phase accumulator
            self.phase_acc = phase_sum
            old_msbs = self.phase_acc_msbs
            new_msbs = (phase_sum >> (NW - 2)) & 0x3
            self.phase_acc_msbs = new_msbs

            # Default: clear all rollover/tclk signals
            self._rollover_pi2 = 0
            self._rollover_pi = 0
            self._rollover_3pi2 = 0
            self._rollover_2pi = 0
            self._tclk_even = 0
            self._tclk_odd = 0

            # Decimation / discard
            if self.discard_count == 0:
                self.discard_count = discard_nco & 0xFF
                self._phase = unsigned(self.phase_acc, NW)

                # Quadrant rollover detection (using registered old_msbs vs new v_phase_acc_msbs)
                if old_msbs == 0b11 and new_msbs == 0b00:
                    self._rollover_2pi = 1
                    self._tclk_odd = 1
                if old_msbs == 0b00 and new_msbs == 0b01:
                    self._rollover_pi2 = 1
                    self._tclk_even = 1
                if old_msbs == 0b01 and new_msbs == 0b10:
                    self._rollover_pi = 1
                    self._tclk_odd = 1
                if old_msbs == 0b10 and new_msbs == 0b11:
                    self._rollover_3pi2 = 1
                    self._tclk_even = 1
            else:
                self.discard_count -= 1

        # LUT lookup (combinational in RTL, but registered output)
        phase_index = (self._phase >> (NW - PW)) & ((1 << PW) - 1)
        self._sin = self.sin_lut[phase_index]
        self._cos = self.cos_lut[phase_index]

        return {
            'phase': self._phase,
            'sin': self._sin,
            'cos': self._cos,
            'rollover_pi2': self._rollover_pi2,
            'rollover_pi': self._rollover_pi,
            'rollover_3pi2': self._rollover_3pi2,
            'rollover_2pi': self._rollover_2pi,
            'tclk_even': self._tclk_even,
            'tclk_odd': self._tclk_odd,
        }


if __name__ == "__main__":
    # Fixed-point test: generate a sine wave
    nco = Nco(nco_w=32, phase_w=10, sinusoid_w=12, fixed_point=True)
    # freq_word for ~1kHz at 61.44 MHz: fw = f * 2^32 / fs
    fw = int(1000 * (2**32) / 61440000)
    print(f"Freq word: {fw} (0x{fw:08x})")

    print("\nFixed-point NCO output (first 20 samples):")
    rollovers = 0
    for i in range(200):
        out = nco.step(enable=1, freq_word=fw)
        if out['rollover_2pi']:
            rollovers += 1
        if i < 20:
            print(f"  [{i:3d}] phase=0x{unsigned(out['phase'], 32):08x}  "
                  f"sin={out['sin']:5d}  cos={out['cos']:5d}  "
                  f"ro_2pi={out['rollover_2pi']}")
    print(f"  Total 2pi rollovers in 200 samples: {rollovers}")

    # Floating-point test
    print("\nFloating-point NCO output:")
    nco_f = Nco(fixed_point=False)
    fw_f = 1000 / 61440000  # normalized frequency
    for i in range(10):
        out = nco_f.step(enable=1, freq_word=fw_f)
        print(f"  [{i}] phase={out['phase']:.6f}  sin={out['sin']:.6f}  cos={out['cos']:.6f}")
