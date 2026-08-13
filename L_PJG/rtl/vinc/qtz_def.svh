`ifndef __DEFINE_SVH__
`define __DEFINE_SVH__

`define FPGA_SOURCE
//`define DISABLE_SV_ASSERTION

`define MAX(a, b) (((a) > (b)) ? (a) : (b))
`define MIN(a, b) (((a) < (b)) ? (a) : (b))

typedef enum int {
    REAL,
    COMPLEX
} dtype_t;

typedef struct packed {
    int sgn_w;
    int int_w;
    int fp_w;
    dtype_t dtype;
    int width;
} qtz_t;

function automatic qtz_t get_qtz(int sgn_w, int int_w, int fp_w, dtype_t dtype);
    get_qtz.sgn_w = sgn_w;
    get_qtz.int_w = int_w;
    get_qtz.fp_w = fp_w;
    get_qtz.dtype = dtype;
    if (dtype == REAL) get_qtz.width = sgn_w + int_w + fp_w;
    else if (dtype == COMPLEX) get_qtz.width = 2 * (sgn_w + int_w + fp_w);
    else $fatal(1, "dtype error");
endfunction

`define COMPLEX_LEFT_SHIFT(value, qtz, shift_len) \
    { \
        {{shift_len{value[qtz.width-1]}}, \
         value[qtz.width-1:SHIFT_LEN + qtz.width/2], \
         {shift_len{value[qtz.width/2-1]}}, \
         value[qtz.width/2-1:SHIFT_LEN]} \
    }

// value transfer utility macro

`define __INT_TRANSFER__(value, qtz_i, qtz_o, int_end_index)\
    {   \
        qtz_o.sgn_w+qtz_o.int_w <= qtz_i.sgn_w+qtz_i.int_w ? \
        value[int_end_index +: ((qtz_o.sgn_w+qtz_o.int_w <= qtz_i.sgn_w+qtz_i.int_w) ? qtz_o.sgn_w+qtz_o.int_w : 1)] : \
        {   \
            {((qtz_o.sgn_w+qtz_o.int_w > qtz_i.sgn_w+qtz_i.int_w) ? qtz_o.sgn_w+qtz_o.int_w-qtz_i.sgn_w-qtz_i.int_w : 1){qtz_i.sgn_w ? value[int_end_index + qtz_i.sgn_w + qtz_i.int_w - 1] : 1'b0}}, \
            value[int_end_index +: ((qtz_o.sgn_w+qtz_o.int_w > qtz_i.sgn_w+qtz_i.int_w) ? qtz_i.sgn_w+qtz_i.int_w : 1)] \
        } \
    }

`define __FP_TRANSFER__(value, qtz_i, qtz_o, fp_head_index)\
    {   \
        qtz_o.fp_w <= qtz_i.fp_w ? \
        value[fp_head_index -: (qtz_o.fp_w <= qtz_i.fp_w ? qtz_o.fp_w : 1)] : \
        { \
            value[fp_head_index -: ((qtz_o.fp_w > qtz_i.fp_w) ? qtz_i.fp_w : 1)], \
            {((qtz_o.fp_w > qtz_i.fp_w) ? qtz_o.fp_w - qtz_i.fp_w : 1){1'b0}} \
        } \
    }

// value transfer macro
// Warning: qtz_o.sgn_w + qtz_o.int_w + qtz_o.fp_w != 0

`define COMPLEX_VALUE_TRANSFER(value, qtz_i, qtz_o) \
    { \
        qtz_o.sgn_w + qtz_o.int_w == 0 ?  \
        { \
            `__FP_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width-qtz_i.sgn_w-qtz_i.int_w-1), \
            `__FP_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width/2-qtz_i.sgn_w-qtz_i.int_w-1) \
        } : \
        qtz_o.fp_w == 0 ?  \
        { \
            `__INT_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width/2), \
            `__INT_TRANSFER__(value, qtz_i, qtz_o, 0) \
        } : \
        { \
            `__INT_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width-qtz_i.sgn_w-qtz_i.int_w), \
            `__FP_TRANSFER__ (value, qtz_i, qtz_o, qtz_i.width-qtz_i.sgn_w-qtz_i.int_w-1), \
            `__INT_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width/2-qtz_i.sgn_w-qtz_i.int_w), \
            `__FP_TRANSFER__ (value, qtz_i, qtz_o, qtz_i.width/2-qtz_i.sgn_w-qtz_i.int_w-1) \
        } \
    }

`define REAL_VALUE_TRANSFER(value, qtz_i, qtz_o) \
    { \
        qtz_o.sgn_w + qtz_o.int_w == 0 ?  \
        { \
            `__FP_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width-qtz_i.sgn_w-qtz_i.int_w-1) \
        } : \
        qtz_o.fp_w == 0 ?  \
        { \
            `__INT_TRANSFER__(value, qtz_i, qtz_o, 0) \
        } : \
        { \
            `__INT_TRANSFER__(value, qtz_i, qtz_o, qtz_i.width-qtz_i.sgn_w-qtz_i.int_w), \
            `__FP_TRANSFER__ (value, qtz_i, qtz_o, qtz_i.width-qtz_i.sgn_w-qtz_i.int_w-1) \
        } \
    }

`define COMMON_PATH_QTZ(data1_qt, data2_qt) \
    (get_qtz(  \
        data1_qt.sgn_w < data2_qt.sgn_w ? data2_qt.sgn_w : data1_qt.sgn_w, \
        data1_qt.int_w < data2_qt.int_w ? data2_qt.int_w : data1_qt.int_w, \
        data1_qt.fp_w < data2_qt.fp_w ? data2_qt.fp_w : data1_qt.fp_w, \
        data1_qt.dtype == REAL && data2_qt.dtype == REAL ? REAL : COMPLEX \
    ))

localparam qtz_t DEFAULT_QTZ = get_qtz(1, 5, 10, REAL);

`endif
