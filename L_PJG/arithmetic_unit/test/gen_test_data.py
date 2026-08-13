#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_test_data.py
================
Golden-data generator for the arithmetic_unit testbenches.

Bit-exact Python reference model of every fixed-point module in
    d:\\cc-connect-agent\\L_PJG\\arithmetic_unit\\*.sv
that reproduces the quantization / truncation macros from
    d:\\cc-connect-agent\\L_PJG\\rtl\\vinc\\qtz_def.svh
(get_qtz, REAL_VALUE_TRANSFER / COMPLEX_VALUE_TRANSFER and their
__INT_TRANSFER__ / __FP_TRANSFER__ sub-macros).

What it does
------------
1. Updates the stimulus files under  test/data/  (existing rows are kept and
   the files are padded up to the number of rows each testbench reads):
     real_input.txt                  (9 rows : 4A + 4B + 1C)
     real_adder_tree_input.txt       (4 rows)
     complex_input.txt               (3 rows : A, B, sub)
     complex_adder_tree_input.txt    (4 rows)
     complex_mac_input.txt           (8 rows : 4A + 4B)
     complex_mac_w_bias_input.txt    (9 rows : 4A + 4B + 1C)
2. Regenerates every  data/out/<module>_expected.txt  golden file with the
   exact width the DUT drives (e.g. Q1.10.10 -> 21-bit -> 6 hex digits).

Run
---
    python gen_test_data.py

No .sv / .bak file is ever modified.
"""

import os

# ---------------------------------------------------------------------------
# Quantization helpers (mirror of qtz_def.svh)
# ---------------------------------------------------------------------------

def q(sgn_w, int_w, fp_w, dtype='REAL'):
    """get_qtz() -- returns a dict {sgn_w,int_w,fp_w,dtype,width}."""
    width = sgn_w + int_w + fp_w
    if dtype == 'COMPLEX':
        width = 2 * (sgn_w + int_w + fp_w)
    return dict(sgn_w=sgn_w, int_w=int_w, fp_w=fp_w, dtype=dtype, width=width)


def clog2(n):
    """$clog2(n) == ceil(log2(n)), n>=1."""
    return (n - 1).bit_length()


def wrap(v, w):
    """Two's-complement truncation of arbitrary int v to w bits (bit pattern)."""
    return v & ((1 << w) - 1)


def sext(v, w):
    """Bit pattern v (w bits) -> Python signed int."""
    v &= (1 << w) - 1
    return v - (1 << w) if (v >> (w - 1)) & 1 else v


def split_complex(v, half_w):
    """{real (high half), imag (low half)} bit patterns of half_w bits."""
    m = (1 << half_w) - 1
    return (v >> half_w) & m, v & m


def qval(v, qtz):
    """Decimal real value of bit pattern v under qtz."""
    v = wrap(v, qtz['width'])
    s = sext(v, qtz['width']) if qtz['sgn_w'] else v
    return s / (2.0 ** qtz['fp_w'])


def hx(v, w):
    """Zero-padded uppercase hex string for a w-bit pattern."""
    return format(wrap(v, w), '0{}X'.format((w + 3) // 4))


# ---------------------------------------------------------------------------
# REAL_VALUE_TRANSFER -- bit-exact port of the qtz_def.svh macros
# ---------------------------------------------------------------------------

def int_transfer(value, qi, qo, int_end_index):
    """`__INT_TRANSFER__(value, qtz_i, qtz_o, int_end_index)"""
    ib_i = qi['sgn_w'] + qi['int_w']
    ib_o = qo['sgn_w'] + qo['int_w']
    if ib_o <= ib_i:
        return (value >> int_end_index) & ((1 << ib_o) - 1)
    ext_bit = ((value >> (int_end_index + ib_i - 1)) & 1) if qi['sgn_w'] else 0
    ext = ext_bit * ((1 << (ib_o - ib_i)) - 1)      # repeated extension bits
    lo = (value >> int_end_index) & ((1 << ib_i) - 1)
    return (ext << ib_i) | lo


def fp_transfer(value, fp_i, fp_o, fp_head_index):
    """`__FP_TRANSFER__(value, qtz_i, qtz_o, fp_head_index)"""
    if fp_o <= fp_i:
        return (value >> (fp_head_index - fp_o + 1)) & ((1 << fp_o) - 1)
    lo = (value >> (fp_head_index - fp_i + 1)) & ((1 << fp_i) - 1)
    return (lo << (fp_o - fp_i)) & ((1 << fp_o) - 1)


def real_value_transfer(value, qi, qo):
    """`REAL_VALUE_TRANSFER(value, qtz_i, qtz_o) -> qo.width-bit pattern."""
    wi = qi['width']
    value &= (1 << wi) - 1
    ib_o = qo['sgn_w'] + qo['int_w']
    fp_i, fp_o = qi['fp_w'], qo['fp_w']
    if ib_o == 0:                                   # pure-fractional output
        return fp_transfer(value, fp_i, fp_o, wi - qi['sgn_w'] - qi['int_w'] - 1)
    if fp_o == 0:                                   # pure-integer output
        return int_transfer(value, qi, qo, 0)
    oi = int_transfer(value, qi, qo, wi - qi['sgn_w'] - qi['int_w'])
    of = fp_transfer(value, fp_i, fp_o, wi - qi['sgn_w'] - qi['int_w'] - 1)
    return (oi << fp_o) | of


# ---------------------------------------------------------------------------
# Module reference models (bit-exact ports of arithmetic_unit/*.sv)
# ---------------------------------------------------------------------------

def model_real_multiplier(a, b, qa, qb, qo):
    """real_multiplier: extend(0-ext) -> signed * -> truncate(Qa.fp+Qb.fp -> Qo)."""
    a_full = sext(a, qa['width']) if qa['sgn_w'] else a
    b_full = sext(b, qb['width']) if qb['sgn_w'] else b
    q_full = q(1, qo['int_w'], qa['fp_w'] + qb['fp_w'], 'REAL')
    prod = wrap(a_full * b_full, q_full['width'])   # HSB truncated to Q1.int+fp
    return real_value_transfer(prod, q_full, qo)


def model_real_adder(a, b, qa, qb, qo, sub=False):
    """real_adder: align -> +/- (int+1) -> truncate."""
    qalign = q(qa['sgn_w'] & qb['sgn_w'],
               max(qa['int_w'], qb['int_w']),
               max(qa['fp_w'], qb['fp_w']), 'REAL')
    a_align = real_value_transfer(a, qa, qalign)
    b_align = real_value_transfer(b, qb, qalign)
    qfull = q(qalign['sgn_w'], qalign['int_w'] + 1, qalign['fp_w'], 'REAL')
    s = (a_align - b_align) if sub else (a_align + b_align)
    full = wrap(s, qfull['width'])
    return real_value_transfer(full, qfull, qo)


def model_real_addsub(a, b, sub, qa, qb, qo):
    return model_real_adder(a, b, qa, qb, qo, sub=bool(sub))


def model_real_negative(a, q_in):
    """real_negative: -InputA (two's complement, same width)."""
    return wrap((~a) + 1, q_in['width'])


def model_real_adder_tree(inputs, qi, qo, add_num):
    """real_adder_tree: N-way accumulate (int + clog2(N) + 1) -> truncate."""
    qfull = q(qi['sgn_w'], qi['int_w'] + clog2(add_num) + 1, qi['fp_w'], 'REAL')
    acc = 0
    for v in inputs:
        acc = wrap(acc + v, qfull['width'])
    return real_value_transfer(acc, qfull, qo)


def model_real_mac(A, B, qa, qb, qo, pairs, C=None, qc=None):
    """real_mac[_w_bias]: extend(sgn_w-based) -> N signed products ->
       accumulate (+clog2(N)) -> truncate.  C (bias) is extended to ACC."""
    prod_fp = qa['fp_w'] + qb['fp_w']
    prod_int = qa['int_w'] + qb['int_w'] + 1
    qprod = q(1, prod_int, prod_fp, 'REAL')
    qacc = q(1, prod_int + clog2(pairs), prod_fp, 'REAL')
    acc = real_value_transfer(C, qc, qacc) if C is not None else 0
    for j in range(pairs):
        af = sext(A[j], qa['width']) if qa['sgn_w'] else A[j]
        bf = sext(B[j], qb['width']) if qb['sgn_w'] else B[j]
        prod = wrap(af * bf, qprod['width'])
        acc = wrap(acc + sext(prod, qprod['width']), qacc['width'])
    return real_value_transfer(acc, qacc, qo)


def _cplx_pre(A, B, qa, qb, qo):
    qar = q(qa['sgn_w'], qa['int_w'], qa['fp_w'], 'REAL')
    qbr = q(qb['sgn_w'], qb['int_w'], qb['fp_w'], 'REAL')
    qor = q(qo['sgn_w'], qo['int_w'], qo['fp_w'], 'REAL')
    ar, ai = split_complex(A, qar['width'])
    br, bi = split_complex(B, qbr['width'])
    ars, ais = sext(ar, qar['width']), sext(ai, qar['width'])
    brs, bis = sext(br, qbr['width']), sext(bi, qbr['width'])
    return qar, qbr, qor, ars, ais, brs, bis


def model_complex_multiplier(A, B, qa, qb, qo, fast=0):
    """complex_multiplier.  fast=0: Gauss 3-mult (x,y,z truncated to
       Q1.int+fp then to Qo).  fast=1: direct 4-mult, single HSB truncation."""
    qar, qbr, qor, ars, ais, brs, bis = _cplx_pre(A, B, qa, qb, qo)
    if fast:
        full_w = qar['width'] + qbr['width']
        crf = wrap(ars * brs - ais * bis, full_w)
        cif = wrap(ais * brs + ars * bis, full_w)
        off = qar['fp_w'] + qbr['fp_w'] - qor['fp_w']
        off_real = off if off > 0 else 0
        bound = min(off + qor['width'], full_w)
        sgn_exp = 0 if (bound - off_real) == qor['width'] \
            else qor['width'] - (bound - off_real)
        def truncate(vf):
            body = (vf >> off_real) & ((1 << (bound - off_real)) - 1)
            sign = (vf >> (bound - 1)) & 1
            return ((sign * ((1 << sgn_exp) - 1) << (bound - off_real)) | body) \
                if sgn_exp else body
        cr, ci = truncate(crf), truncate(cif)
    else:
        qarp = q(qa['sgn_w'], qa['int_w'] + 1, qa['fp_w'], 'REAL')
        qbrp = q(qb['sgn_w'], qb['int_w'] + 1, qb['fp_w'], 'REAL')
        qprod = q(1, qor['int_w'], qar['fp_w'] + qbrp['fp_w'], 'REAL')
        ar_sub_ai = wrap(ars - ais, qarp['width'])
        ar_add_ai = wrap(ars + ais, qarp['width'])
        br_add_bi = wrap(brs + bis, qbrp['width'])
        xf = wrap(ars * sext(br_add_bi, qbrp['width']), qprod['width'])
        yf = wrap(sext(ar_add_ai, qarp['width']) * bis, qprod['width'])
        zf = wrap(sext(ar_sub_ai, qarp['width']) * brs, qprod['width'])
        x = real_value_transfer(xf, qprod, qor)
        y = real_value_transfer(yf, qprod, qor)
        z = real_value_transfer(zf, qprod, qor)
        cr = wrap(x - y, qor['width'])
        ci = wrap(x - z, qor['width'])
    return (cr << qor['width']) | ci


def model_complex_adder(A, B, qa, qb, qo, sub=0):
    return model_complex_addsub(A, B, sub, qa, qb, qo)


def model_complex_addsub(A, B, sub, qa, qb, qo):
    qar, qbr, qor, ars, ais, brs, bis = _cplx_pre(A, B, qa, qb, qo)
    ar, ai = split_complex(A, qar['width'])
    br, bi = split_complex(B, qbr['width'])
    or_ = model_real_addsub(ar, br, sub, qar, qbr, qor)
    oi = model_real_addsub(ai, bi, sub, qar, qbr, qor)
    return (or_ << qor['width']) | oi


def model_complex_conj(A, q_in):
    half = q_in['width'] // 2
    r, i = split_complex(A, half)
    return (r << half) | wrap((~i) + 1, half)


def model_complex_negative(A, q_in):
    half = q_in['width'] // 2
    r, i = split_complex(A, half)
    return (wrap((~r) + 1, half) << half) | wrap((~i) + 1, half)


def model_complex_adder_tree(inputs, qi, qo, add_num):
    qir = q(qi['sgn_w'], qi['int_w'], qi['fp_w'], 'REAL')
    qor = q(qo['sgn_w'], qo['int_w'], qo['fp_w'], 'REAL')
    qfull = q(qi['sgn_w'], qi['int_w'] + clog2(add_num) + 1, qi['fp_w'], 'REAL')
    rs = [split_complex(v, qir['width'])[0] for v in inputs]
    iss = [split_complex(v, qir['width'])[1] for v in inputs]
    full_r = model_real_adder_tree(rs, qir, qfull, add_num)
    full_i = model_real_adder_tree(iss, qir, qfull, add_num)
    or_ = real_value_transfer(full_r, qfull, qor)
    oi = real_value_transfer(full_i, qfull, qor)
    return (or_ << qor['width']) | oi


def model_complex_real_multiplier(C_in, R, qc, qr, qo):
    qcr = q(qc['sgn_w'], qc['int_w'], qc['fp_w'], 'REAL')
    qor = q(qo['sgn_w'], qo['int_w'], qo['fp_w'], 'REAL')
    cr, ci = split_complex(C_in, qcr['width'])
    or_ = model_real_multiplier(cr, R, qcr, qr, qor)
    oi = model_real_multiplier(ci, R, qcr, qr, qor)
    return (or_ << qor['width']) | oi


def model_complex_mac(A, B, qa, qb, qo, pairs, fast=0, C=None, qc=None):
    """complex_mac[_w_bias]: split -> extend(sgn_w) -> per-pair complex
       product (Gauss 3-mult or direct 4-mult) at ACC width -> accumulate ->
       truncate.  C (bias) extended to ACC."""
    qar, qbr, qor, _, _, _, _ = _cplx_pre(A[0], B[0], qa, qb, qo)
    qarp = q(qa['sgn_w'], qa['int_w'] + 1, qa['fp_w'], 'REAL')
    qbrp = q(qb['sgn_w'], qb['int_w'] + 1, qb['fp_w'], 'REAL')
    if fast:
        qacc = q(1, qar['int_w'] + qbr['int_w'] + 1 + 1 + clog2(pairs),
                 qar['fp_w'] + qbr['fp_w'], 'REAL')
    else:
        qacc = q(1, qar['int_w'] + qbrp['int_w'] + 1 + 1 + clog2(pairs),
                 qar['fp_w'] + qbrp['fp_w'], 'REAL')
    Acc_r = 0
    Acc_i = 0
    if C is not None:
        qcr = q(qc['sgn_w'], qc['int_w'], qc['fp_w'], 'REAL')
        cr, ci = split_complex(C, qcr['width'])
        Acc_r = real_value_transfer(cr, qcr, qacc)
        Acc_i = real_value_transfer(ci, qcr, qacc)
    for j in range(pairs):
        ars, ais = _cplx_pre(A[j], B[j], qa, qb, qo)[3:5]
        _, _, _, _, _, brs, bis = _cplx_pre(A[j], B[j], qa, qb, qo)
        if fast:
            ar_br = wrap(ars * brs, qacc['width'])
            ai_bi = wrap(ais * bis, qacc['width'])
            ai_br = wrap(ais * brs, qacc['width'])
            ar_bi = wrap(ars * bis, qacc['width'])
            pr = wrap(ar_br - ai_bi, qacc['width'])
            pi = wrap(ai_br + ar_bi, qacc['width'])
        else:
            ar_add_ai = wrap(ars + ais, qarp['width'])
            ar_sub_ai = wrap(ars - ais, qarp['width'])
            br_add_bi = wrap(brs + bis, qbrp['width'])
            xf = wrap(ars * sext(br_add_bi, qbrp['width']), qacc['width'])
            yf = wrap(sext(ar_add_ai, qarp['width']) * bis, qacc['width'])
            zf = wrap(sext(ar_sub_ai, qarp['width']) * brs, qacc['width'])
            pr = wrap(xf - yf, qacc['width'])
            pi = wrap(xf - zf, qacc['width'])
        Acc_r = wrap(Acc_r + pr, qacc['width'])
        Acc_i = wrap(Acc_i + pi, qacc['width'])
    or_ = real_value_transfer(Acc_r, qacc, qor)
    oi = real_value_transfer(Acc_i, qacc, qor)
    return (or_ << qor['width']) | oi


def model_complex_mac_w_bias(A, B, C, qa, qb, qc, qo, pairs, fast=0):
    return model_complex_mac(A, B, qa, qb, qo, pairs, fast=fast, C=C, qc=qc)


# ---------------------------------------------------------------------------
# Testbench quantization parameters (copied from the *_tb.sv localparams)
# ---------------------------------------------------------------------------
QA  = q(1, 9, 6, 'REAL')       # real A    (16-bit)
QB  = q(1, 4, 5, 'REAL')       # real B    (10-bit)
QC  = q(1, 6, 7, 'REAL')       # real C    (14-bit, MAC bias)
QO  = q(1, 10, 10, 'REAL')     # real out  (21-bit)
CA  = q(1, 9, 6, 'COMPLEX')    # complex A (32-bit)
CB  = q(1, 4, 5, 'COMPLEX')    # complex B (20-bit)
CC  = q(1, 6, 7, 'COMPLEX')    # complex C (28-bit, MAC bias)
CO  = q(1, 10, 10, 'COMPLEX')  # complex out (42-bit)

# ---------------------------------------------------------------------------
# Stimulus files -- defaults used to (re)pad; existing rows are preserved
# ---------------------------------------------------------------------------
DEFAULTS = {
    'real_input.txt':              ['7fff', '8000', '3fff', 'C250',
                                    '000A', '0010', '0020', '0040', '0100'],
    'real_adder_tree_input.txt':   ['7fff', '8000', '3fff', '4000'],
    'complex_input.txt':           ['7fff8000', '80007fff', '3fff0000'],
    'complex_adder_tree_input.txt':['7fff8000', '80007fff', '3fff0000', '00003fff'],
    'complex_mac_input.txt':       ['2B20E1E0', '040B7067', 'E0A3BBF3', '4DB5F049',
                                    '0280A', '04008', '02806', '08010'],
    'complex_mac_w_bias_input.txt':['E5871854', '19F4BD43', '30EDE440', '84C96A8B',
                                    '04002', '04006', '0800A', '0800E', '0400080'],
}


def read_lines(path):
    if not os.path.exists(path):
        return []
    with open(path, 'r') as f:
        return [ln.strip() for ln in f if ln.strip() != '']


def ensure_input_file(path, defaults):
    """Keep existing rows, pad with defaults up to the required count."""
    existing = read_lines(path)
    merged = list(existing)
    if len(merged) < len(defaults):
        merged += defaults[len(merged):]
    with open(path, 'w') as f:
        f.write('\n'.join(merged) + '\n')
    return merged


# ---------------------------------------------------------------------------
# Expected-output writers
# ---------------------------------------------------------------------------
def write_expected(name, value, qtz):
    path = os.path.join(OUT_DIR, name + '_expected.txt')
    with open(path, 'w') as f:
        f.write(hx(value, qtz['width']) + '\n')
    return path


def show(module, lines, qo, value):
    w = qo['width']
    print('  Expected = 0x{}  (Q1.{}.{}, {} bits, real={:.6f})'.format(
        hx(value, w), qo['int_w'], qo['fp_w'], w, qval(value, qo)))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main():
    global OUT_DIR
    HERE = os.path.dirname(os.path.abspath(__file__))
    DATA_DIR = os.path.join(HERE, 'data')
    OUT_DIR = os.path.join(DATA_DIR, 'out')
    os.makedirs(OUT_DIR, exist_ok=True)

    print('=' * 72)
    print(' STEP 1 : regenerate / pad stimulus files (data/*.txt)')
    print('=' * 72)
    files = {}
    for fname, default in DEFAULTS.items():
        lines = ensure_input_file(os.path.join(DATA_DIR, fname), default)
        files[fname] = lines
        print('  %-34s %2d rows : %s' % (fname, len(lines), ' '.join(lines)))

    def inp(fname):
        return files[fname]

    print()
    print('=' * 72)
    print(' STEP 2 : compute + write expected outputs (data/out/*_expected.txt)')
    print('=' * 72)

    # ---- real testbenches ------------------------------------------------
    real = inp('real_input.txt')
    a0 = int(real[0], 16) & ((1 << QA['width']) - 1)
    b0 = int(real[1], 16) & ((1 << QB['width']) - 1)
    b1 = int(real[2], 16) & ((1 << QB['width']) - 1)   # (unused by most)
    sub = int(real[2], 16) != 0

    print('\n[real_multiplier]')
    print('  InputA=0x%s  InputB=0x%s' % (hx(a0, QA['width']), hx(b0, QB['width'])))
    v = model_real_multiplier(a0, b0, QA, QB, QO)
    show('real_multiplier', real, QO, v)
    write_expected('real_multiplier', v, QO)

    print('\n[real_adder]')
    print('  InputA=0x%s  InputB=0x%s' % (hx(a0, QA['width']), hx(b0, QB['width'])))
    v = model_real_adder(a0, b0, QA, QB, QO, sub=False)
    show('real_adder', real, QO, v)
    write_expected('real_adder', v, QO)

    print('\n[real_addsub]')
    print('  InputA=0x%s  InputB=0x%s  sub=%d' % (hx(a0, QA['width']), hx(b0, QB['width']), int(sub)))
    v = model_real_addsub(a0, b0, sub, QA, QB, QO)
    show('real_addsub', real, QO, v)
    write_expected('real_addsub', v, QO)

    print('\n[real_negative]')
    print('  InputA=0x%s' % hx(a0, QA['width']))
    v = model_real_negative(a0, QA)
    show('real_negative', real, QA, v)
    write_expected('real_negative', v, QA)

    print('\n[real_adder_tree]')
    tree = [int(x, 16) & ((1 << QA['width']) - 1) for x in inp('real_adder_tree_input.txt')]
    for i, t in enumerate(tree):
        print('  Input[%d]=0x%s' % (i, hx(t, QA['width'])))
    v = model_real_adder_tree(tree, QA, QO, 4)
    show('real_adder_tree', tree, QO, v)
    write_expected('real_adder_tree', v, QO)

    print('\n[real_mac]  (pairs=4, no bias)')
    Am = [int(real[i], 16) & ((1 << QA['width']) - 1) for i in range(4)]
    Bm = [int(real[4 + i], 16) & ((1 << QB['width']) - 1) for i in range(4)]
    for i in range(4):
        print('  A[%d]=0x%s  B[%d]=0x%s' % (i, hx(Am[i], QA['width']), i, hx(Bm[i], QB['width'])))
    v = model_real_mac(Am, Bm, QA, QB, QO, 4)
    show('real_mac', real, QO, v)
    write_expected('real_mac', v, QO)

    print('\n[real_mac_w_bias]  (pairs=4, bias C)')
    Cm = int(real[8], 16) & ((1 << QC['width']) - 1)
    print('  C=0x%s  (Q1.%d.%d = %.4f)' % (hx(Cm, QC['width']), QC['int_w'], QC['fp_w'], qval(Cm, QC)))
    v = model_real_mac(Am, Bm, QA, QB, QO, 4, C=Cm, qc=QC)
    show('real_mac_w_bias', real, QO, v)
    write_expected('real_mac_w_bias', v, QO)

    # ---- complex testbenches ---------------------------------------------
    cplx = inp('complex_input.txt')
    cA = int(cplx[0], 16) & ((1 << CA['width']) - 1)
    cB = int(cplx[1], 16) & ((1 << CB['width']) - 1)   # TB truncates to 20-bit
    cR = int(cplx[1], 16) & ((1 << QB['width']) - 1)   # TB truncates to 10-bit
    csub = int(cplx[2], 16) != 0

    print('\n[complex_multiplier]  (FAST=0, Gauss 3-mult)')
    print('  InputA=0x%s  InputB=0x%s(trunc 20bit)' % (hx(cA, CA['width']), hx(cB, CB['width'])))
    v = model_complex_multiplier(cA, cB, CA, CB, CO, fast=0)
    show('complex_multiplier', cplx, CO, v)
    write_expected('complex_multiplier', v, CO)

    print('\n[complex_adder]')
    print('  InputA=0x%s  InputB=0x%s' % (hx(cA, CA['width']), hx(cB, CB['width'])))
    v = model_complex_adder(cA, cB, CA, CB, CO, sub=0)
    show('complex_adder', cplx, CO, v)
    write_expected('complex_adder', v, CO)

    print('\n[complex_addsub]')
    print('  InputA=0x%s  InputB=0x%s  sub=%d' % (hx(cA, CA['width']), hx(cB, CB['width']), int(csub)))
    v = model_complex_addsub(cA, cB, csub, CA, CB, CO)
    show('complex_addsub', cplx, CO, v)
    write_expected('complex_addsub', v, CO)

    print('\n[complex_conj]')
    print('  InputA=0x%s' % hx(cA, CA['width']))
    v = model_complex_conj(cA, CA)
    show('complex_conj', cplx, CA, v)
    write_expected('complex_conj', v, CA)

    print('\n[complex_negative]')
    print('  InputA=0x%s' % hx(cA, CA['width']))
    v = model_complex_negative(cA, CA)
    show('complex_negative', cplx, CA, v)
    write_expected('complex_negative', v, CA)

    print('\n[complex_adder_tree]  (ADD_NUM=4)')
    ctree = [int(x, 16) & ((1 << CA['width']) - 1) for x in inp('complex_adder_tree_input.txt')]
    for i, t in enumerate(ctree):
        print('  Input[%d]=0x%s' % (i, hx(t, CA['width'])))
    v = model_complex_adder_tree(ctree, CA, CO, 4)
    show('complex_adder_tree', ctree, CO, v)
    write_expected('complex_adder_tree', v, CO)

    print('\n[complex_real_multiplier]')
    print('  complex_in=0x%s  real_in=0x%s(trunc 10bit)' % (hx(cA, CA['width']), hx(cR, QB['width'])))
    v = model_complex_real_multiplier(cA, cR, CA, QB, CO)
    show('complex_real_multiplier', cplx, CO, v)
    write_expected('complex_real_multiplier', v, CO)

    print('\n[complex_mac]  (pairs=4, no bias, FAST=0)')
    cAm = [int(inp('complex_mac_input.txt')[i], 16) & ((1 << CA['width']) - 1) for i in range(4)]
    cBm = [int(inp('complex_mac_input.txt')[4 + i], 16) & ((1 << CB['width']) - 1) for i in range(4)]
    for i in range(4):
        print('  A[%d]=0x%s  B[%d]=0x%s' % (i, hx(cAm[i], CA['width']), i, hx(cBm[i], CB['width'])))
    v = model_complex_mac(cAm, cBm, CA, CB, CO, 4, fast=0)
    show('complex_mac', cAm, CO, v)
    write_expected('complex_mac', v, CO)

    print('\n[complex_mac_w_bias]  (pairs=4, bias C, FAST=0)')
    wb = inp('complex_mac_w_bias_input.txt')
    wAm = [int(wb[i], 16) & ((1 << CA['width']) - 1) for i in range(4)]
    wBm = [int(wb[4 + i], 16) & ((1 << CB['width']) - 1) for i in range(4)]
    wCm = int(wb[8], 16) & ((1 << CC['width']) - 1)
    print('  C=0x%s  (Q1.%d.%d = %.4f)' % (hx(wCm, CC['width']), CC['int_w'], CC['fp_w'], qval(wCm, CC)))
    v = model_complex_mac_w_bias(wAm, wBm, wCm, CA, CB, CC, CO, 4, fast=0)
    show('complex_mac_w_bias', wb, CO, v)
    write_expected('complex_mac_w_bias', v, CO)

    print()
    print('=' * 72)
    print(' DONE : stimulus + expected files regenerated.')
    print(' Expected output widths: real=21b(6 hex), real_negative=16b(4 hex),')
    print('   complex=42b(11 hex), conj/negative=32b(8 hex).')
    print('=' * 72)


if __name__ == '__main__':
    main()
