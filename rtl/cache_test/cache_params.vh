`ifndef _cache_params_vh_
`define _cache_params_vh_
parameter BLOCKSIZE = 64;

//L1 Cache properties
parameter L1_CACHESIZE = 1024;
parameter L1_ASSOC = 2;
parameter L1_NUMSETS = L1_CACHESIZE/(BLOCKSIZE * L1_ASSOC);

//L2 Cache properties
parameter L2_CACHESIZE = 8192;
parameter L2_ASSOC = 16;
parameter L2_NUMSETS = L2_CACHESIZE/(BLOCKSIZE * L2_ASSOC);
`endif