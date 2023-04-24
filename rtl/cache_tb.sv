`timescale 1ns / 1ps
//`include "trace_addr.sv"
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

module cache_tb();
    reg clk, reset;
    reg write_policy, replace_policy;
    reg inclusion_policy;
    reg[47:0] cache_addr;
    reg[7:0] cache_op;
    wire[17:0] L1_reads, L1_writes, L1_misses, L1_hits;
    wire[17:0] L2_reads, L2_writes, L2_misses, L2_hits;
    wire[31:0] curr_tag_L1, curr_tag_L2;
    wire[31:0] cache1 [0:L1_NUMSETS-1][0:L1_ASSOC-1];
    wire[31:0] cache2 [0:L2_NUMSETS-1][0:L2_ASSOC-1];
    parameter SIZE = 100000;
    reg[47:0] test_addrs[0:SIZE-1];
    reg[7:0] test_ops[0:SIZE-1];
    real L1_miss_rate, L2_miss_rate;
    real L1misses, L1reads, L1hits, L1writes;
    real L2misses, L2reads, L2hits, L2writes;
    
    
    cache_engine UUT(
        .clk(clk), 
        .reset(reset), 
        .write_policy(write_policy), 
        .replace_policy(replace_policy),
        .inclusion_policy(inclusion_policy),
        .cache_addr(cache_addr),
        .L1_reads(L1_reads),
        .L1_writes(L1_writes),
        .L1_misses(L1_misses),
        .L1_hits(L1_hits),
        .L2_reads(L2_reads),
        .L2_writes(L2_writes),
        .L2_misses(L2_misses),
        .L2_hits(L2_hits),
        .curr_tag_L1(curr_tag_L1),
        .curr_tag_L2(curr_tag_L2),
        .cache_op(cache_op),
        .curr_set_L1(curr_set_L1),
        .L1_cache(cache1),
        .L2_cache(cache2)
        );
    integer i;
    
    /*                                   SIMULATION INPUTS
    ************************************************************************************************
        replace_policy: 0 -> FIFO | 1 -> LRU
        
        write_policy: 0 -> write-through | 1 -> write-back
        
        inclusion_policy: 0 -> inclusive | 1 -> exclusive | 2 -> non-inclusive
        
        cache_lvl: 0 -> L2 | 1 -> L1
    ************************************************************************************************   
    */
    initial begin
        $readmemh("C:/Users/JohnG/Desktop/Codes/School/CDA5106/rtl/traces/gcc_trace_addresses.txt", test_addrs, 0, 99999);
        $readmemh("C:/Users/JohnG/Desktop/Codes/School/CDA5106/rtl/traces/gcc_trace_actions.txt", test_ops, 0, 99999);
        replace_policy = 1;
        write_policy = 1;
        inclusion_policy = 1;
        clk = 1;
        reset = 1;
        #10
        reset = 0;
        //send an addr and op from array to top module
        for(i = 0; i < SIZE; i=i+1)begin
            cache_addr = test_addrs[i];
            cache_op = test_ops[i];
            //cache_lvl = test_cache_lvl[i];
            #10;
        end
        
        // L1 stats
        L1misses = L1_misses;
        L1reads = L1_reads;
        L1hits = L1_hits;
        L1writes = L1_writes;
        L1_miss_rate = L1misses / (L1hits+L1misses);
        
        //L2 stats
        L2misses = L2_misses;
        L2reads = L2_reads;
        L2hits = L2_hits;
        L2writes = L2_writes;
        L2_miss_rate = L2misses / (L2hits+L2misses);
    end
    
    always #1 clk = ~clk;

endmodule
