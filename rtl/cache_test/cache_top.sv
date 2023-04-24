`timescale 1ns / 1ps
`include "cache_params.vh"
//////////////////////////////////////////////////////////////////////////////////
// Company: UCF
// Engineers: John Gierlach & Harrison Lipton
// 
// Create Date: 03/16/2023 12:43:31 AM
// Design Name: 
// Module Name: cache_top
// Project Name: Multi-level Cache project
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module cache_top(
  input clk,
  input reset,
  input write_policy,
  input[47:0] cache_addr,
  input[7:0] cache_op,
  output reg[17:0] L1_reads, L1_misses, L1_hits, L1_writes,
  output reg[17:0] L2_reads, L2_misses, L2_hits, L2_writes
);

  // write_policy: 0 -> write through | 1 -> write back                         DONE
  // replace_policy: 0 -> FIFO | 1 -> LRU                                       DONE
  // inclusion_policy: 0 -> inclusive | 2 -> non-inclusive                      DONE
  // cache_op: W or R
  reg[31:0] L1_cache [0:L1_NUMSETS-1][0:L1_ASSOC-1];
  reg[31:0] L2_cache [0:L2_NUMSETS-1][0:L2_ASSOC-1];
  reg[31:0] L1_index;         
  reg[31:0] L1_tag;
  
  reg[31:0] L2_index;         
  reg[31:0] L2_tag;
    
  cache_engine cache_block
  (     .clk(clk), 
        .reset(reset), 
        .write_policy(write_policy), 
        .cache_addr(cache_addr),
        .L1_reads(L1_reads),
        .L1_writes(L1_writes),
        .L1_misses(L1_misses),
        .L1_hits(L1_hits),
        .L2_reads(L2_reads),
        .L2_writes(L2_writes),
        .L2_misses(L2_misses),
        .L2_hits(L2_hits),
        .cache_op(cache_op),
        .L1_index(L1_index),
        .L2_index(L2_index),
        .L1_tag(L1_tag),
        .L2_tag(L2_tag),
        .L1_cache(L1_cache),
        .L2_cache(L2_cache)
   );
   
endmodule