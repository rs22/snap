#include <ap_int.h>
#include <hls_stream.h>

typedef struct axi_datamover_status {
    ap_uint<8> data;
    ap_uint<1> keep;
    ap_uint<1> last;
} axi_datamover_status_t;
typedef hls::stream<axi_datamover_status_t> axi_datamover_status_stream_t;

typedef ap_uint<103> axi_datamover_command_t;
typedef hls::stream<axi_datamover_command_t> axi_datamover_command_stream_t;
