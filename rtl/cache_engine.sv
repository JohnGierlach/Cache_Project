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

module cache_engine(
      input clk,
      input reset,
      input write_policy,
      input replace_policy,
      input inclusion_policy,
      input[47:0] cache_addr,
      input[7:0] cache_op,
      output reg[31:0] curr_tag_L1,
      output reg[31:0] curr_tag_L2,
      output reg[11:0] curr_set_L1,
      output reg[11:0] curr_set_L2,
      output reg[17:0] L1_reads, L1_misses, L1_hits, L1_writes,
      output reg[17:0] L2_reads, L2_misses, L2_hits, L2_writes,
      output reg[31:0] L1_tag, L1_index, L2_tag, L2_index,
      output reg[31:0] L1_cache [0:L1_NUMSETS-1][0:L1_ASSOC-1],
      output reg[31:0] L2_cache [0:L2_NUMSETS-1][0:L2_ASSOC-1]
    );
    
    
  // FSM Regs and Parameters
  parameter IDLE = 0, READ = 1, SEARCH = 2, SHIFTFULL = 3, SHIFTEMPTY = 4, CACHEHIT = 5, DONE = 6;
  reg[3:0] state, next_state;
  reg[47:0] prev_addr;
  
  // Counter variables
  reg      L1_found, L2_found;
  integer i, j, L1_lru_index, L2_lru_index;
  
  // Temporary variables
  reg [31:0] back_inval;
  
  // Replacement policy FSM | Combinational logic
  always@(*)begin
   
    case(state)
        
        // Idle state for cache, keep cache state value the same
        IDLE: next_state <= (cache_addr != 0) ? READ:IDLE;
        
        // Read in address to find tag, index, and block off-set
        READ: next_state <= SEARCH;
        
        // Search for tag state
        SEARCH:begin
            // FIFO
            if(replace_policy == 0)begin
                next_state <= (L1_found | L2_found) ? CACHEHIT:(L1_cache[L1_index][L1_ASSOC-1] != 0 || L2_cache[L2_index][L2_ASSOC-1]) ? SHIFTFULL:SHIFTEMPTY;
            end

            // LRU | If cache hit, go to LRUHIT logic, if cache miss proceed with FIFO-like shifitng
            else
                next_state <= (L1_found | L2_found) ? CACHEHIT:(L1_cache[L1_index][L1_ASSOC-1] != 0 || L2_cache[L2_index][L2_ASSOC-1]) ? SHIFTFULL:SHIFTEMPTY;
        end
        
        // Shift if current cache is Full FIFO or Full LRU Miss
        SHIFTFULL: next_state <= DONE;

        // Shfit if current cache is not Full in FIFO or LRU
        SHIFTEMPTY: next_state <= DONE;
        
        // Shift logic in case of LRU hit
        CACHEHIT: next_state <= DONE; 
        
        // Finish Shift operations, calculate miss rate, and jump into ideal
        DONE: next_state <= IDLE;
        
    endcase
  end
  
  // Sequential Logic for setting up FSM and initializing values
  always@(posedge clk)begin

    // Initialize values for testing
    if(reset)begin
        state <= IDLE;
        L1_misses <= 12'b0;
        L1_hits <= 12'b0;
        L1_reads <= 12'b0;
        L1_writes <= 12'b0;
        L2_misses <= 12'b0;
        L2_hits <= 12'b0;
        L2_reads <= 12'b0;
        L2_writes <= 12'b0;
        curr_set_L1 <= 12'b0;
        curr_tag_L1 <= 32'b0;
        curr_set_L2 <= 12'b0;
        curr_tag_L2 <= 32'b0;
        L1_found <= 1'b0;
        L2_found <= 1'b0;
        prev_addr <= 48'b0;
        back_inval <= 32'b0;

        // Clear for L1
        for(i = 0; i < L1_NUMSETS; i = i + 1)begin
            for(j = 0; j < L1_ASSOC; j = j + 1)begin
                L1_cache[i][j] = 32'b0;
            end
        end

        // Clear for L2
        for(i = 0; i < L2_NUMSETS; i = i + 1)begin
            for(j = 0; j < L2_ASSOC; j = j + 1)begin
                L2_cache[i][j] = 32'b0;
            end
        end
    end
    
    // Flexible Cache Logic
    else begin
        state <= next_state;
        
        // If an address has been read, increment reads, get tag & index for FSM
        if(next_state == READ)begin
        
            // L1 Cache input
            L1_tag <= cache_addr / (BLOCKSIZE * L1_NUMSETS);                   // Current Tag address derived from the input cache address
            L1_index <= (cache_addr / BLOCKSIZE) % L1_NUMSETS;                 // Current Set that the tag will go into
            curr_tag_L1 <= L1_tag;
            
            // L2 Cache input
            L2_tag <= cache_addr / (BLOCKSIZE * L2_NUMSETS);                   // Current Tag address derived from the input cache address
            L2_index <= (cache_addr / BLOCKSIZE) % L2_NUMSETS;                 // Current Set that the tag will go into
            curr_tag_L2 <= L2_tag;
            // If write through & W operation increment writes
            if(write_policy == 0 && cache_op == 8'h57)begin
                  L1_writes <= L1_writes + 1;
                  L2_writes <= L2_writes + 1;
            end
            
        end
        
        // Search for the tag within the current replacement policy, write policy, and inclusion policy
        else if(next_state == SEARCH)begin

            // FIFO 
            if(replace_policy == 0)begin
                
                // L1 Cache | If tag found in cache, mark as found and mark LRU tag index
                for(i = 0; i < L1_ASSOC; i = i + 1)begin        
                    if(L1_tag == L1_cache[L1_index][i])begin
                            L1_found <= 1'b1;
                            L1_hits <= L1_hits + 1;
                            break;
                    end
                end               

                // L2 Cache | If tag found in cache, mark as found and mark LRU tag index
                for(i = 0; i < L2_ASSOC; i = i + 1)begin        
                    if(L2_tag == L2_cache[L2_index][i])begin
                            L2_found <= 1'b1;
                            break;
                    end
                end 
            end
            
            // LRU
            else begin
                
                // L1 Cache | If tag found in cache, mark as found and mark LRU tag index
                for(i = 0; i < L1_ASSOC; i = i + 1)begin        
                    if(L1_tag == L1_cache[L1_index][i])begin
                            L1_found <= 1'b1;
                            L1_hits <= L1_hits + 1;
                            L1_lru_index = i;
                            break;
                    end
                end               

                // L2 Cache | If tag found in cache, mark as found and mark LRU tag index
                for(i = 0; i < L2_ASSOC; i = i + 1)begin        
                    if(L2_tag == L2_cache[L2_index][i])begin
                            L2_found <= 1'b1;
                            L2_lru_index = i;
                            break;
                    end
                end            
            end                   
        end
        
        // Shift logic if the cache for LRU or FIFO is full
        else if(next_state == SHIFTFULL)begin
        
                if(replace_policy == 1 || replace_policy == 0)begin
                    L1_misses <= L1_misses + 1;
                    L1_reads <= L1_reads + 1;
                    L2_misses <= L2_misses + 1;
                    L2_reads <= L2_misses + 1;
                    if(write_policy == 1 && cache_op == 7'h57)begin
                        L1_writes <= L1_writes + 1;
                        L2_writes <= L2_writes + 1;
                    end     
                end


                // If replace policy is inclusive and L1 & L2 miss
                if(inclusion_policy == 0)begin
                
                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                        L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                    end
                    
                    // Case for back invalidation
                    if(L2_cache[L2_index][L2_ASSOC-1] != 0)begin
                        back_inval <= L1_tag;
                        L2_cache[L2_index][L2_ASSOC-1] <= 32'b0;
                        
                        for(i = L1_ASSOC - 1; i >= 0; i = i - 1)begin
                            
                            if(back_inval == L1_tag)
                                L1_cache[L1_index][i] <= 32'b0;
                            
                        end
                        
                    end
                    
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L2_ASSOC-1; i >= 0; i = i - 1)begin
                        L2_cache[L2_index][i] <= L2_cache[L2_index][i-1];
                    end
                            
                    L2_cache[L2_index][0] <= L2_tag;
                        
                end
                                
                // If the current inclusion policy is Non-inclusive and L1 & L2 miss, then insert tag in both caches
                if(inclusion_policy == 1)begin
                
                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L1_ASSOC; i > 0; i = i - 1)begin
                        L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                    end
                    
                    if(L2_cache[L2_index][L2_ASSOC-1] != 0)
                        L2_cache[L2_index][L2_ASSOC-1] <= 32'b0;
                    
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L2_ASSOC; i > 0; i = i - 1)begin
                        L2_cache[L2_index][i] <= L2_cache[L2_index][i-1];
                    end
                            
                    L2_cache[L2_index][0] <= L2_tag;
                        
                end    
                // Insert new address at beginning of cache line
                L1_cache[L1_index][0] <= L1_tag;
        end
        
        // Shift logic if the cache for LRU or FIFO isn't full
        else if(next_state == SHIFTEMPTY)begin

                if(replace_policy == 1 || replace_policy == 0)begin
                    L1_misses <= L1_misses + 1;
                    L1_reads <= L1_reads + 1;
                    L2_misses <= L2_misses + 1;
                    L2_reads <= L2_misses + 1;
                    if(write_policy == 1 && cache_op == 7'h57)begin
                        L1_writes <= L1_writes + 1;
                        L2_writes <= L2_writes + 1;
                   end     
               end

                
                // If replace policy is inclusive and L1 & L2 miss
                if(inclusion_policy == 0)begin
                
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                        L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                    end
                    // Pop out last address out of cache before shifting
                    L1_cache[L1_index][0] <= L1_tag;
                                
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L2_ASSOC-1; i >= 0; i = i - 1)begin
                        L2_cache[L2_index][i] <= L2_cache[L2_index][i-1];
                    end
                            
                    L2_cache[L2_index][0] <= L2_tag;
                        
                end
                
                // If the current inclusion policy is Non-inclusive and L1 & L2 miss, then insert tag in both caches
                if(inclusion_policy == 1)begin
                
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                        L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                    end
                    // Pop out last address out of cache before shifting
                    L1_cache[L1_index][0] <= L1_tag;
                                
                    // Shifts through the current set with the size of the cache line to shift in FIFO order
                    for(i = L2_ASSOC-1; i >= 0; i = i - 1)begin
                        L2_cache[L2_index][i] <= L2_cache[L2_index][i-1];
                    end
                            
                    L2_cache[L2_index][0] <= L2_tag;
                        
                end    
        end

        // Shift logic for LRU hit
        else if(next_state == CACHEHIT)begin

                if(replace_policy == 1)begin
                    
                    // L1 cache
                    if(L1_found)begin
                        // Pop out LRU hit tag out of cache before shifting
                        L1_cache[L1_index][L1_lru_index] <= 32'b0;
                            
                        // Shifts through the current set with the size of the cache line to shift in LRU order
                        for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                        
                            if(i <= L1_lru_index)
                                L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                        end
                        
                        // If (inclusion policy is inclusive and L1 hits while L2 misses) == false
                        if(!(inclusion_policy == 0 && !L2_found)) begin  
                        
                            // If the inclusion policy is exclusive and L2 hits, evict L2 before we insert to L1
                            // This will always be tested in exclusive mode as the previous if statement is always true in exclusive
                            
                            
                            // Insert new address at beginning of cache line
                            L1_cache[L1_index][0] <= L1_tag;    
                        end
                    end
    
                    // L2 cache
                    else if(!L1_found && L2_found) begin
                        L2_hits <= L2_hits + 1;
                        L1_misses <= L1_misses + 1;
                        L1_reads <= L1_reads + 1;
                        if(write_policy == 1 && cache_op == 7'h57)begin
                            L1_writes <= L1_writes + 1;
                        end     
                        // Pop out LRU hit tag out of cache before shifting
                        L2_cache[L2_index][L2_lru_index] <= 32'b0;
                            
                        // Shifts through the current set with the size of the cache line to shift in LRU order
                        for(i = L2_ASSOC; i > 0; i = i - 1)begin
                            
                            if(i <= L2_lru_index)
                                L2_cache[L2_index][i] <= L2_cache[L2_index][i-1];
                        end
                            
                        L2_cache[L2_index][0] <= L2_tag;
                        
                        // If replace policy is inclusive and L1 miss & L2 hit
                        if(inclusion_policy == 0)begin
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            if(L2_index > L1_ASSOC-1)begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L1_index][L1_ASSOC-1] != 0)
                                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i > 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the 1st L1 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end
                                
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            else begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L2_index][L1_ASSOC-1] != 0)
                                    L1_cache[L2_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i > 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the L2 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end   
                        end
                        
                        // If replace policy is non-inclusive
                        if(inclusion_policy == 1)begin
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            if(L2_index > L1_ASSOC-1)begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L1_index][L1_ASSOC-1] != 0)
                                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the 1st L1 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end
                                
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            else begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L1_index][L1_ASSOC-1] != 0)
                                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L2_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the L2 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end 
                          
                        end
                    end    
                end
                
                else begin
                    // L2 cache
                    if(!L1_found && L2_found) begin
                        L2_hits <= L2_hits + 1;
                        L1_misses <= L1_misses + 1;
                        L1_reads <= L1_reads + 1;
                        if(write_policy == 1 && cache_op == 7'h57)begin
                            L1_writes <= L1_writes + 1;
                        end

                        // If replace policy is exclusive and L1 miss & L2 hit
                       
                        // If replace policy is inclusive and L1 miss & L2 hit
                        if(inclusion_policy == 0)begin
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            if(L2_index > L1_ASSOC-1)begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L1_index][L1_ASSOC-1] != 0)
                                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i > 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the 1st L1 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end
                                
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            else begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L2_index][L1_ASSOC-1] != 0)
                                    L1_cache[L2_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i > 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the L2 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end   
                        end
                        
                        // If replace policy is non-inclusive
                        if(inclusion_policy == 1)begin
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            if(L2_index > L1_ASSOC-1)begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L1_index][L1_ASSOC-1] != 0)
                                    L1_cache[L1_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the 1st L1 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end
                                
                            // If the current L2 set is outside the range of the L1 sets, then write tag to 1st L1 set
                            else begin
                                // Pop out last address out of cache before shifting
                                if(L1_cache[L2_index][L1_ASSOC-1] != 0)
                                    L1_cache[L2_index][L1_ASSOC-1] <= 32'b0;
                                        
                                // Shifts through the current set with the size of the cache line to shift in FIFO order
                                for(i = L1_ASSOC-1; i >= 0; i = i - 1)begin
                                    L1_cache[L1_index][i] <= L1_cache[L1_index][i-1];
                                end
                                    
                                // Insert tag entry from L2 into L1 Set from the L2 Set 
                                L1_cache[L1_index][0] <= L1_tag;
                            end   
                        end
                    end
                end
                
                L1_found <= 1'b0;
                L2_found <= 1'b0;
        end
    end
  end
endmodule