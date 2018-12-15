/*
 * Copyright 2017 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <string.h>
#include "ap_int.h"
#include "hls_action.H"
#include "axi_datamover.h"

//----------------------------------------------------------------------
//--- MAIN PROGRAM -----------------------------------------------------
//----------------------------------------------------------------------
static int process_action(
	action_reg *act_reg,
	axi_datamover_command_stream_t &mm2s_cmd,
	axi_datamover_status_stream_t &mm2s_sts,
	axi_datamover_command_stream_t &s2mm_cmd,
	axi_datamover_status_stream_t &s2mm_sts)
{
    const int N = 64; // Address width (host mem)
    const uint64_t DRAM_OFFSET = 1 << 63;

    uint32_t size;
    uint64_t i_idx, o_idx;

    /* byte address received need to be aligned with port width */
    i_idx = act_reg->Data.in.addr;
    o_idx = act_reg->Data.out.addr;
    size = act_reg->Data.in.size;

    if (act_reg->Data.in.type == SNAP_ADDRTYPE_CARD_DRAM)
        i_idx += DRAM_OFFSET;
    if (act_reg->Data.out.type == SNAP_ADDRTYPE_CARD_DRAM)
        o_idx += DRAM_OFFSET;

    {
        #pragma HLS dataflow

        { // Read Data
            uint64_t bytes_read = 0;
            while (bytes_read < size) {
                // Stream data in block-sized chunks (64K)
                uint64_t bytes_remaining = size - bytes_read;
                snap_bool_t end_of_frame = bytes_remaining <= 1<<16;
                ap_uint<23> read_bytes = end_of_frame ? bytes_remaining : 1<<16;

                axi_datamover_command_t cmd = 0;
                cmd((N+31), 32) = i_idx + bytes_read;
                cmd[30] = end_of_frame;
                cmd[23] = 1; // AXI burst type: INCR
                cmd(22, 0) = read_bytes;
                mm2s_cmd.write(cmd);

                bytes_read += read_bytes;

                mm2s_sts.read();
            }
        }

        { // Write Data
            uint64_t bytes_written = 0;
            while (bytes_written < size) {
                // Write data in block-sized chunks (64K)
                uint64_t bytes_remaining = size - bytes_written;
                snap_bool_t end_of_frame = bytes_remaining <= 1<<16;
                ap_uint<23> write_bytes = end_of_frame ? bytes_remaining : 1<<16;

                axi_datamover_command_t cmd = 0;
                cmd((N+31), 32) = o_idx + bytes_written;
                cmd[30] = end_of_frame;
                cmd[23] = 1; // AXI burst type: INCR
                cmd(22, 0) = write_bytes;
                s2mm_cmd.write(cmd);

                bytes_written += write_bytes;

                s2mm_sts.read();
            }
        }
    }

    act_reg->Control.Retc = SNAP_RETC_SUCCESS;
    return 0;
}

//--- TOP LEVEL MODULE -------------------------------------------------
void hls_action(
	snap_membus_t *din_gmem,
	snap_membus_t *dout_gmem,
	action_reg *act_reg,
	action_RO_config_reg *Action_Config,
	axi_datamover_command_stream_t &mm2s_cmd,
	axi_datamover_status_stream_t &mm2s_sts,
	axi_datamover_command_stream_t &s2mm_cmd,
	axi_datamover_status_stream_t &s2mm_sts)
{
    // Host Memory AXI Interface - CANNOT BE REMOVED - NO CHANGE BELOW
#pragma HLS INTERFACE m_axi port=din_gmem bundle=host_mem offset=slave depth=512 \
  max_read_burst_length=64  max_write_burst_length=64
#pragma HLS INTERFACE s_axilite port=din_gmem bundle=ctrl_reg offset=0x030

#pragma HLS INTERFACE m_axi port=dout_gmem bundle=host_mem offset=slave depth=512 \
  max_read_burst_length=64  max_write_burst_length=64
#pragma HLS INTERFACE s_axilite port=dout_gmem bundle=ctrl_reg offset=0x040

    // Host Memory AXI Lite Master Interface - NO CHANGE BELOW
#pragma HLS DATA_PACK variable=Action_Config
#pragma HLS INTERFACE s_axilite port=Action_Config bundle=ctrl_reg offset=0x010
#pragma HLS DATA_PACK variable=act_reg
#pragma HLS INTERFACE s_axilite port=act_reg bundle=ctrl_reg offset=0x100
#pragma HLS INTERFACE s_axilite port=return bundle=ctrl_reg

    // AXI Data Mover interface
#pragma HLS INTERFACE axis port=mm2s_cmd
#pragma HLS INTERFACE axis port=mm2s_sts
#pragma HLS INTERFACE axis port=s2mm_cmd
#pragma HLS INTERFACE axis port=s2mm_sts

    if (act_reg->Data.in.type == 0x815) {
        // If we don't use the host memory interfaces anywhere, Vivado HLS doesn't generate the
        // C_M_AXI_HOST_MEM_USER_VALUE, C_M_AXI_HOST_MEM_PROT_VALUE, C_M_AXI_HOST_MEM_CACHE_VALUE signals
        dout_gmem[4711] = din_gmem[0x1234];
    }

    /* Required Action Type Detection - NO CHANGE BELOW */
    //	NOTE: switch generates better vhdl than "if" */
    // Test used to exit the action if no parameter has been set.
    // Used for the discovery phase of the cards */
    switch (act_reg->Control.flags) {
    case 0:
	Action_Config->action_type = HELLOWORLD_ACTION_TYPE;
	Action_Config->release_level = RELEASE_LEVEL;
	act_reg->Control.Retc = 0xe00f;
	return;
	break;
    default:
	    process_action(act_reg, mm2s_cmd, mm2s_sts, s2mm_cmd, s2mm_sts);
	break;
    }
}

//-----------------------------------------------------------------------------
//-- TESTBENCH BELOW IS USED ONLY TO DEBUG THE HARDWARE ACTION WITH HLS TOOL --
//-----------------------------------------------------------------------------

#ifdef NO_SYNTH

int main(void)
{
#define MEMORY_LINES 1
    int rc = 0;
    unsigned int i;
    static snap_membus_t  din_gmem[MEMORY_LINES];
    static snap_membus_t  dout_gmem[MEMORY_LINES];

    //snap_membus_t  dout_gmem[2048];
    //snap_membus_t  d_ddrmem[2048];
    action_reg act_reg;
    action_RO_config_reg Action_Config;

    // Discovery Phase .....
    // when flags = 0 then action will just return action type and release
    act_reg.Control.flags = 0x0;
    printf("Discovery : calling action to get config data\n");
    hls_action(din_gmem, dout_gmem, &act_reg, &Action_Config);
    fprintf(stderr,
	"ACTION_TYPE:	%08x\n"
	"RELEASE_LEVEL: %08x\n"
	"RETC:		%04x\n",
	(unsigned int)Action_Config.action_type,
	(unsigned int)Action_Config.release_level,
	(unsigned int)act_reg.Control.Retc);

    // Processing Phase .....
    // Fill the memory with 'c' characters
    memset(din_gmem,  'c', sizeof(din_gmem[0]));
    printf("Input is : %s\n", (char *)((unsigned long)din_gmem + 0));

    // set flags != 0 to have action processed
    act_reg.Control.flags = 0x1; /* just not 0x0 */

    act_reg.Data.in.addr = 0;
    act_reg.Data.in.size = 64;
    act_reg.Data.in.type = SNAP_ADDRTYPE_HOST_DRAM;

    act_reg.Data.out.addr = 0;
    act_reg.Data.out.size = 64;
    act_reg.Data.out.type = SNAP_ADDRTYPE_HOST_DRAM;

    printf("Action call \n");
    hls_action(din_gmem, dout_gmem, &act_reg, &Action_Config);
    if (act_reg.Control.Retc == SNAP_RETC_FAILURE) {
	fprintf(stderr, " ==> RETURN CODE FAILURE <==\n");
	return 1;
    }

    printf("Output is : %s\n", (char *)((unsigned long)dout_gmem + 0));

    printf(">> ACTION TYPE = %08lx - RELEASE_LEVEL = %08lx <<\n",
		    (unsigned int)Action_Config.action_type,
		    (unsigned int)Action_Config.release_level);
    return 0;
}

#endif
