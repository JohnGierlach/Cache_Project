import java.awt.List;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.Scanner;

class Block {
    int tag;
    long address;
    boolean dirty;
    boolean valid;

    public Block() {
        tag = 0;
        address = 0;
        dirty = true;
        valid = false;
    }
}

class CacheLevel
{
    long cacheSize;
    int blockSize;
    int associativity;
    int numSets;
    ArrayList<LinkedList<Integer>> tagArray;
    ArrayList<LinkedList<Block>> blockArray;
    ArrayList<Long> allTraces;
    int replacementPolicy; // 1 = lru, 2 = fifo, 3 = optimal

    int reads;
    int readMisses;
    int writes;
    int writeMisses;
    int writebacks;
    int counter;

    // int misses;
    // int hits;
    // int writes;
    // int reads;


    public CacheLevel(int assoc, long size, int block, int replacement, ArrayList<Long> allTraces)
    {
        this.cacheSize = size;
        this.blockSize = block;
        this.associativity = assoc;
        this.replacementPolicy = replacement;
        // this.misses = 0;
        // this.hits = 0;
        this.writes = 0;
        this.reads = 0;
        this.readMisses = 0;
        this.writeMisses = 0;
        this.allTraces = allTraces;
        this.counter = 0;

        this.numSets = (int)(this.cacheSize / (long)(this.blockSize * this.associativity));
        this.tagArray = new ArrayList<LinkedList<Integer>>();
        this.blockArray = new ArrayList<LinkedList<Block>>();

        for (int i = 0; i < this.numSets; i++) {
            this.tagArray.add(new LinkedList<Integer>());
            this.blockArray.add(new LinkedList<Block>());
        }
    }

    Block performOperation(char op, int setNumber, int tag, long address)
    {
        if (op == 'w')
        {
            return performWrite(setNumber, tag, address);
        }
        else
        {
            return performRead(setNumber, tag, address);
        }
    }

    Block performWrite(int setNumber, int tag, long address)
    {   
        int index = getIndexOfTag(setNumber, tag);

        Block removedBlock = new Block();
        removedBlock.valid = false;

        //write hit
        if (index != -1)
        {
            //update the dirty bit on a write hit
            Block curBlock = blockArray.get(setNumber).get(index);
            curBlock.dirty = true;
            blockArray.get(setNumber).set(index, curBlock);

            if (replacementPolicy == 1)
            {
                updateLRU(setNumber, tag);
            }

            this.writes++;

            return removedBlock;
        }
        else
        {
            this.writeMisses++;
            this.writes++;

            Block newBlock = new Block();
            newBlock.dirty = true;
            newBlock.tag = tag;
            newBlock.valid = true;
            newBlock.address = address;

            if (tagArray.get(setNumber).size() < this.associativity)
            {
                //insert to both without worrying, no need to evict because there is space left
                addToLinkedLists(setNumber, tag, newBlock);
                return removedBlock;
            }

            if (replacementPolicy == 3)
            {
                Block evictedBlock = doOptimalReplacement(setNumber, newBlock);
                evictedBlock.valid = true;
                if (evictedBlock.dirty == true)
                {
                    writebacks++;
                }
                return evictedBlock;
            }
            else
            {
                //perform LRU/FIFO replacement
                LinkedList<Integer> curSet1 = tagArray.get(setNumber);
                LinkedList<Block> curSet2 = blockArray.get(setNumber);

                int removedTag = curSet1.removeLast();
                removedBlock = curSet2.removeLast();

                //deal with dirty bits as necessary
                if (removedBlock.dirty == true)
                {
                    this.writebacks++;
                }
                //add new elements to replacement linked lists
                curSet1.addFirst(tag);
                curSet2.addFirst(newBlock);

                tagArray.set(setNumber, curSet1);
                blockArray.set(setNumber, curSet2);
            }

            //make sure its valid so I can use the evicted block later
            removedBlock.valid = true;
            return removedBlock;
        }
    }

    Block performRead(int setNumber, int tag, long address) {
        int index = getIndexOfTag(setNumber, tag);

        Block removedBlock = new Block();
        removedBlock.valid = false;

        // the tag was found in the cache
        if (index != -1) {
            if (replacementPolicy == 1 || replacementPolicy == 3) {
                updateLRU(setNumber, tag);
            }
            
            this.reads++;
            return removedBlock;
        }
        else 
        {
            this.readMisses++;
            this.reads++;

            //create the new block to insert
            Block newBlock = new Block();
            newBlock.tag = tag;
            newBlock.dirty = false;
            newBlock.valid = true;
            newBlock.address = address;

            // cache set is not full
            if (tagArray.get(setNumber).size() < this.associativity) {
                // insert to both without worrying, no need to evict because there is space left
                addToLinkedLists(setNumber, tag, newBlock);
                return removedBlock;
            }

            // cache set is full
            // optimal replacement policy placeholder
            if (replacementPolicy == 3) {
                // perform optimal replacement
                Block evictedBlock = doOptimalReplacement(setNumber, newBlock);
                evictedBlock.valid = true;
                if (evictedBlock.dirty == true)
                {
                    writebacks++;
                }
                return evictedBlock;
            } else {
                // perform LRU/FIFO replacement
                LinkedList<Integer> curSet1 = tagArray.get(setNumber);
                LinkedList<Block> curSet2 = blockArray.get(setNumber);

                int removedTag = curSet1.removeLast();
                removedBlock = curSet2.removeLast();

                //deal with dirty bits as necessary
                if (removedBlock.dirty == true)
                {
                    this.writebacks++;
                }
                //add new elements to replacement linked lists
                curSet1.addFirst(tag);
                curSet2.addFirst(newBlock);

                tagArray.set(setNumber, curSet1);
                blockArray.set(setNumber, curSet2);
            }

            removedBlock.valid = true;
            return removedBlock;
        }
    }

    int getIndexOfTag(int setNumber, int tag) {
        boolean condition = false; 
        LinkedList<Block> curSet = blockArray.get(setNumber);
        for (Block currBlock : curSet)
        {
            if (currBlock.valid && currBlock.tag == tag)
            {
                condition = true;
            }
        }

        if (condition)
        {
            return tagArray.get(setNumber).indexOf(tag);
        }
        else
        {
            return -1;
        }
    }

    void updateLRU(int setNumber, int tag) {
        LinkedList<Integer> curSet1 = tagArray.get(setNumber);
        LinkedList<Block> curSet2 = blockArray.get(setNumber);

        int index = curSet1.indexOf(tag);

        int tagToUpdate = curSet1.remove(index);
        Block blockToUpdate = curSet2.remove(index);

        curSet1.addFirst(tagToUpdate);
        curSet2.addFirst(blockToUpdate);

        tagArray.set(setNumber, curSet1);
        blockArray.set(setNumber, curSet2);
    }

    void addToLinkedLists(int setNumber, int tag, Block block) {
        LinkedList<Integer> curSet1 = tagArray.get(setNumber);
        curSet1.addFirst(tag);
        tagArray.set(setNumber, curSet1);

        LinkedList<Block> curSet2 = blockArray.get(setNumber);
        curSet2.addFirst(block);
        blockArray.set(setNumber, curSet2);
    }

    Block doOptimalReplacement(int setNumber, Block newBlock)
    {
        //get necessary sublist
        ArrayList<Long> currentTrace = new ArrayList<Long>(this.allTraces.subList(counter, this.allTraces.size()));
        int maxIndex = -1;
        int indexToRemove = -1;
        int i = 0;
        boolean found = false;
        
        // System.out.println("Current set: " + this.tagArray.get(setNumber).toString());
        //loop over all blocks
        LinkedList<Integer> setTags = this.tagArray.get(setNumber);
        LinkedList<Block> setBlocks = this.blockArray.get(setNumber);
        // System.out.println("At line " + (counter + 1));
        // System.out.println("The current set " + setNumber + " is: " + String.format("0x%08X", setBlocks.get(0).address) + " and " + String.format("0x%08X", setBlocks.get(1).address));
        for (i = 0; i < setBlocks.size(); i++)
        {
            //get the next time the memory address is used
            Block currBlock = setBlocks.get(i);
            int indexInList = currentTrace.indexOf(currBlock.address);
            // System.out.println("Address " + String.format("0x%08X", setBlocks.get(i).address) + " was found at index " + indexInList);
            //if the next time is further than the current furthest, mark as furthest
            //save the index in the list to remove
            if (indexInList == -1)
            {
                indexToRemove = i;
                found = true;
                break;
            }
            if (indexInList > maxIndex)
            {
                maxIndex = indexInList;
                indexToRemove = i;
            }
            
            //increase the current index being searched
        }

        //catch statement for when not found in trace
        if ((indexToRemove == -1) && (!found))
        {
            indexToRemove = this.blockArray.get(setNumber).size() - 1;
        }

        //remove the old element from the linked list and tag arrays
        LinkedList<Block> curBlockArray= blockArray.get(setNumber);
        LinkedList<Integer> curTagArray = tagArray.get(setNumber);

        Block removedBlock = curBlockArray.remove(indexToRemove);
        curTagArray.remove(indexToRemove);

        curBlockArray.add(indexToRemove, newBlock);
        curTagArray.add(indexToRemove, newBlock.tag);

        this.tagArray.set(setNumber, curTagArray);
        this.blockArray.set(setNumber, curBlockArray);

        // System.out.println("Evicted: " + String.format("0x%08X", removedBlock.address));
        return removedBlock;
    }

    Boolean contains(int setNumber, int tag)
    {
        boolean condition = false; 
        LinkedList<Block> curSet = blockArray.get(setNumber);
        for (Block currBlock : curSet)
        {
            if (currBlock.valid && currBlock.tag == tag)
            {
                condition = true;
            }
        }
        
        return /*tagArray.get(setNumber).contains(tag) &&*/ condition;
    }

    void printStats()
    {
        System.out.printf("Miss Ratio: %.6f\n", (double)(this.readMisses + this.writeMisses) / (this.reads + this.writes));
        System.out.println("Writes: " + writes);
        System.out.println("Reads: " + reads);
        System.out.println("Write Misses: " + this.writeMisses);
        System.out.println("Read Misses: " + this.readMisses);
        System.out.println("Writebacks: " + this.writebacks);
    }

    void printCache()
    {
        System.out.println("======== Contents =======");
        for (int i = 0; i < this.numSets; i++)
        {
            LinkedList<Block> curSet = blockArray.get(i);
            System.out.print("Set " + i + "    ");
            for (Block curBlock : curSet)
            {
                System.out.print(Integer.toHexString(curBlock.tag) + " ");
                if(curBlock.dirty == true)
                {
                    System.out.print("D  ");
                }
                else
                {
                    System.out.print("   ");
                }
            }
            System.out.println();
        }
    }
}

class OverallCache
{
    CacheLevel L1;
    CacheLevel L2;
    int inclusion;

    public OverallCache(int l1Assoc, int l1Size, int l2Assoc, int l2Size, int block, int replacement, int inclusion, ArrayList<Long> allTraces)
    {
        this.L1 = new CacheLevel(l1Assoc, l1Size, block, replacement, allTraces);
        this.L2 = new CacheLevel(l2Assoc, l2Size, block, replacement, allTraces);
        this.inclusion = inclusion;
    }

    public OverallCache(int l1Assoc, int l1Size, int block, int replacement, int inclusion, ArrayList<Long> allTraces)
    {
        this.L1 = new CacheLevel(l1Assoc, l1Size, block, replacement, allTraces);
        this.inclusion = inclusion;
    }

    void startOperation(char op, int L1SetNumber, int L1Tag, int L2SetNumber, int L2Tag, long address)
    {
        int state = -1;
        boolean L1Contains = L1.contains(L1SetNumber, L1Tag);
        boolean L2Contains = L2.contains(L2SetNumber, L2Tag);

        if (L1Contains && L2Contains)
        {
            state = 0;
        }
        else if (L1Contains && !L2Contains)
        {
            state = 1;
        }
        else if (!L1Contains && L2Contains)
        {
            state = 2;
        }
        else
        {
            state = 3;
        }

        if (this.inclusion == 1)
        {
            executeNoninclusive(op, state, L1SetNumber, L1Tag, L2SetNumber, L2Tag, address);
        }
        else if (this.inclusion == 2)
        {
            executeInclusive(op, state, L1SetNumber, L1Tag, L2SetNumber, L2Tag, address);
        }
    }

    void executeNoninclusive(char op, int state, int L1SetNumber, int L1Tag, int L2SetNumber, int L2Tag, long address)
    {
        if (state == 0)
        {
            //exists in both, nothing will be evicted, just leave it alone
            L1.performOperation(op, L1SetNumber, L1Tag, address);
            L2.performOperation(op, L2SetNumber, L2Tag, address);
        }
        else if (state == 1)
        {
            //exists only in l1, deal with eviction but do nothing else
            // L2.misses++;
            Block evicted = L1.performOperation(op, L1SetNumber, L1Tag, address);

            if(evicted.valid)
            {
                int newL2SetNumber = (int)(evicted.address % this.L2.numSets);
                int newL2Tag = (int)(evicted.address / this.L2.numSets);
                this.L2.performOperation('w', newL2SetNumber, newL2Tag, evicted.address);
            }
        }
        else if (state == 2)
        {
            //exists only in l2, move it into l1, deal with the eviction it causes
            L2.performOperation(op, L2SetNumber, L2Tag, address);
            Block evicted = L1.performOperation(op, L1SetNumber, L1Tag, address);

            if (evicted.valid)
            {
                int newL2SetNumber =(int)(evicted.address % this.L2.numSets);
                int newL2Tag = (int)(evicted.address / this.L2.numSets);
                this.L2.performOperation('w', newL2SetNumber, newL2Tag, evicted.address);
            }
            // L1.reads--; //subtracting one to account for copying from L2, not memory
        }
        else if (state == 3)
        {
            //doesnt exist in either, handle the eviction from l1
            Block evicted = L1.performOperation(op, L1SetNumber, L1Tag, address);
            L2.performOperation(op, L2SetNumber, L2Tag, address);

            if (evicted.valid)
            {
                int newL2SetNumber = (int)(evicted.address % this.L2.numSets);
                int newL2Tag = (int)(evicted.address / this.L2.numSets);
                this.L2.performOperation('w', newL2SetNumber, newL2Tag, evicted.address);
            }
        }
    }

    void executeInclusive(char op, int state, int L1SetNumber, int L1Tag, int L2SetNumber, int L2Tag, long address)
    {
        if (state == 0 || state == 3)
        {
            L1.performOperation(op, L1SetNumber, L1Tag, address);
            L2.performOperation(op, L2SetNumber, L2Tag, address);
        }
        else if (state == 2)
        {
            L2.performOperation(op, L2SetNumber, L2Tag, address);
            L1.performOperation(op, L1SetNumber, L1Tag, address);
            L1.reads--; //subtracting one to account for copying from L2, not memory
        }

        //if l2 doesnt contain tag and l1 contains tag
        boolean L2Contains = L2.contains(L2SetNumber, L2Tag);
        boolean L1Contains = L1.contains(L1SetNumber, L1Tag);

        if (L1Contains && !L2Contains)
        {
            LinkedList<Block> curSet = L1.blockArray.get(L1SetNumber);
            for (int i = 0; i < curSet.size(); i++)
            {
                Block curBlock = curSet.get(i);
                if (curBlock.tag == L1Tag)
                {
                    curBlock.valid = false;
                    curSet.set(i, curBlock);
                    break;
                }
            }
            L1.blockArray.set(L1SetNumber, curSet);
        }
    }
}

class CacheSim
{
    public static void main(String[] args) throws FileNotFoundException
    {
        // get the input from the command line in the following order:
        // <BLOCKSIZE> <L1_SIZE> <L1_ASSOC> <L2_SIZE> <L2_ASSOC> <REPLACEMENT_POLICY>
        // <INCLUSION_PROPERTY> <trace_file>
        int blockSize = Integer.parseInt(args[0]);
        int l1Size = Integer.parseInt(args[1]);
        int l1Assoc = Integer.parseInt(args[2]);
        int l2Size = Integer.parseInt(args[3]);
        int l2Assoc = Integer.parseInt(args[4]);
        String replacementPolicy = args[5];
        String inclusionProperty = args[6];
        String traceFile = args[7];

        ArrayList<Long> allTraces = scanInAddresses(traceFile);
        // System.out.println(allTraces.toString());

        // convert the replacement policy to an integer
        int replacementPolicyInt = -1;
        if (replacementPolicy.equals("LRU")) {
            replacementPolicyInt = 1;
        } else if (replacementPolicy.equals("FIFO")) {
            replacementPolicyInt = 2;
        } else if (replacementPolicy.equals("OPTIMAL")) {
            replacementPolicyInt = 3;
        }

        // convert the inclusion property to an integer
        int inclusionPropertyInt = -1;
        if (inclusionProperty.equals("non-inclusive")) {
            inclusionPropertyInt = 1;
        } else if (inclusionProperty.equals("inclusive")) {
            inclusionPropertyInt = 2;
        } else if (inclusionProperty.equals("exclusive")) {
            inclusionPropertyInt = 3;
        }

        boolean L2Exists = (l2Size > 0 ? true : false);
        System.out.println(L2Exists);
        OverallCache cache;
        if (L2Exists)
        {
            cache = new OverallCache(l1Assoc, l1Size, l2Assoc, l2Size, blockSize, replacementPolicyInt, inclusionPropertyInt, allTraces);
        }
        else
        {
            cache = new OverallCache(l1Assoc, l1Size, blockSize, replacementPolicyInt, inclusionPropertyInt, allTraces);
        }

        Scanner in = new Scanner(new File(traceFile));

        if (L2Exists)
        {
            while (in.hasNext())
            {
                String nextLine = in.nextLine();
                char op = nextLine.charAt(0);
                long address = Long.parseLong(nextLine.substring(2), 16);
                address = address / cache.L1.blockSize;
                int L1SetNumber = (int)(address % cache.L1.numSets);
                int L2SetNumber = (int)(address % cache.L2.numSets);
                int L1Tag = (int)(address / cache.L1.numSets);
                int L2Tag = (int)(address / cache.L2.numSets);
                
                //execute operation
                cache.startOperation(op, L1SetNumber, L1Tag, L2SetNumber, L2Tag, address);
                cache.L1.counter++;
                cache.L2.counter++;
            }
            System.out.println("L1:");
            cache.L1.printStats();
            cache.L1.printCache();
            System.out.println();
            System.out.println("L2:");
            cache.L2.printStats();
            cache.L2.printCache();
        }
        else
        {
            //l2 does not exist execution
            while (in.hasNext())
            {
                String nextLine = in.nextLine();
                char op = nextLine.charAt(0);
                long address = Long.parseLong(nextLine.substring(2), 16);
                address = address / cache.L1.blockSize;
                // System.out.println(String.format("0x%08X", address));
                int L1SetNumber = (int)(address % cache.L1.numSets);
                int L1Tag = (int)(address / cache.L1.numSets);
                
                // System.out.println("Address: " + String.format("0x%08X", address));
                // System.out.println("Set Number: " + L1SetNumber);
                // System.out.println("Tag: " + String.format("0x%08X", L1Tag));
                // System.out.println();

                //execute operation
                cache.L1.performOperation(op, L1SetNumber, L1Tag, address);
                cache.L1.counter++;
                
            }

            // while(in.hasNext()) 
            // {
            //     // System.out.println("iteration " + counter);
            //     String line = in.nextLine();
            //     char op = line.charAt(0);
            //     String temp = "0" + line.substring(4);
            //     BigInteger bigAddress = new BigInteger(temp, 16);
            //     bigAddress = bigAddress.divide(new BigInteger("" + cache.L1.blockSize));
            //     //address /= cache.blockSize;
            //     long address = bigAddress.longValue();
            //     int setNumber = (int)(address % cache.L1.numSets);
            //     int tag = (int)(address / cache.L1.numSets);

            //     // System.out.println(setNumber);
            //     // System.out.println(tag);
            //     cache.L1.performOperation(op, setNumber, tag); 
            // }

            cache.L1.printStats();
            cache.L1.printCache();
            // cache.L2.printStats();
        }
    }

    static ArrayList<Long> scanInAddresses(String traceFile) throws FileNotFoundException
    {
        Scanner scanFile = new Scanner(new File(traceFile));
        ArrayList<Long> listOfAddresses = new ArrayList<Long>();
        while(scanFile.hasNext())
        {
            String nextLine = scanFile.nextLine();
            nextLine = nextLine.substring(2);
            long address = Long.parseLong(nextLine, 16);
            address /= 16;
            listOfAddresses.add(address);
        }

        return listOfAddresses;
    }
}