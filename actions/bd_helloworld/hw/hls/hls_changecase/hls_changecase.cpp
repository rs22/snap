#include <hls_stream.h>
#include <ap_int.h>

typedef struct axis_element {
    ap_uint<512> data;
    ap_uint<64> keep;
    ap_uint<1> last;
} axis_element_t;

void hls_changecase(hls::stream<axis_element> in, hls::stream<axis_element> out) {
    #pragma HLS INTERFACE axis port=in
    #pragma HLS INTERFACE axis port=out
    #pragma HLS INTERFACE ap_ctrl_none port=return

    while (true) {
        axis_element element = in.read();
        for (int i = 0; i < sizeof(element.data); ++i)
        {
#pragma HLS unroll
            ap_uint<8> tmp = element.data(i * 8 + 7, i * 8);
            if (tmp >= 'a' && tmp <= 'z')
                element.data(i * 8 + 7, i * 8) = tmp - ('a' - 'A');
        }
        out.write(element);
    }
}
