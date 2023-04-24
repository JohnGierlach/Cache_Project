#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include "ourHeaders.h"

typedef struct CacheLevel
{
    int level;
    int cacheSize;
    int associativity;
    int sets;
} CacheLevel;

int loadFile(int argc, char *argv[]);
bool isPowerOfTwo(int x);
int getInputs();
CacheLevel *getCacheLevel(int level);
int getSets(int cacheSize, int associativity);
CacheLevel *createCacheLevel(int level, int cacheSize, int associativity, int numSets);
void printInputs(char *traceFile);
void printCache();

// global variables
int BLOCK_SIZE = -1;
int REPLACEMENT_POLICY = -1;
int INCLUSION_POLICY = -1;
int NUM_OF_CACHE_LEVELS = -1;
FILE *INPUT_FILE = NULL;

CacheLevel **MAIN_CACHE = NULL;

// grab arguments from command line
int main(int argc, char *argv[])
{
    // load file, -1 means error
    if (loadFile(argc, argv) == -1)
    {
        return 1;
    }

    // get inputs from user, -1 means error
    while (getInputs() == -1)
    {
        printf(">>> Failed to get inputs, please retry\n");
    }

    // read file for debuging
    char line[256];
    while (fgets(line, sizeof(line), INPUT_FILE)) {
        printf("%s", line);
    }

    // print the raw chache structs for debuging
    printCache();
    
    printInputs(argv[1]);

    // close file
    fclose(INPUT_FILE);

    // this is in case someone whants to 
    // experiment with header files
    // hello_world();

    return 0;
}

int loadFile(int argc, char *argv[])
{
    // check if there is a file path
    if (argc != 2)
    {
        // we did it this way so we dont have to type out the whole thing
        // every time we want to run the program
        printf("Usage: ./cacheSim <tracefile path>\n");
        return -1;
    }

    INPUT_FILE = fopen(argv[1], "r");

    // check if file opened
    if (INPUT_FILE == NULL)
    {
        printf("Could not open file.\n");
        return -1;
    }

    return 0;
}

// function to check if a number is a power of 2
bool isPowerOfTwo(int x)
{
    // 8 is 1000
    // 7 is 0111,
    // so 8 & 7 = 0

    // 7 is 0111
    // 6 is 0110
    // so 7 & 6 = 6 or essentiall not 0

    return !(x & (x - 1));
}

// function to get the inputs from the user
int getInputs()
{
    int inputSize = 256;
    char input[inputSize];

    // Block Size
    while (true)
    {
        printf("Block Size: \n");
        if (fgets(input, inputSize, stdin) == NULL)
        {
            printf(">>> Failed to read Block Size\n");
        }

        // convert input string to int
        BLOCK_SIZE = atoi(input);

        // safeguard for bad input
        if (BLOCK_SIZE <= 0)
        {
            printf(">>> Must be a positive integer greater than 1\n");
        }
        else if (!isPowerOfTwo(BLOCK_SIZE))
        {
            printf(">>> Must be a power of 2\n");
        }
        else
        {
            break;
        }
    }

    // Replacement Policy
    while (true)
    {
        printf("Replacement policy?: \n    1:\tLRU\n    2:\tFIFO\n    3:\tOptimal\n");
        if (fgets(input, inputSize, stdin) == NULL)
        {
            printf(">>> Failed to read Replacement Policy\n");
        }

        // convert input string to int
        REPLACEMENT_POLICY = atoi(input);

        // safeguard for bad input
        if (REPLACEMENT_POLICY == 1 || REPLACEMENT_POLICY == 2 || REPLACEMENT_POLICY == 3)
        {
            break;
        }
        else
        {
            printf(">>> Invalid selection, must be 1, 2, or 3\n");
        }
    }

    // Inclusion policy
    while (true)
    {
        printf("Inclusion policy?: \n    1:\tInclusive\n    2:\tExclusive\n    3:\tNon-inclusive\n");
        if (fgets(input, inputSize, stdin) == NULL)
        {
            printf(">>> Failed to read Inclusion Policy\n");
        }

        // convert input string to int
        INCLUSION_POLICY = atoi(input);

        // safeguard for bad input
        if (INCLUSION_POLICY == 1 || INCLUSION_POLICY == 2 || INCLUSION_POLICY == 3)
        {
            break;
        }
        else
        {
            printf(">>> Invalid selection, must be 1 or 2\n");
        }
    }

    // Amount of Levels
    while (true)
    {
        printf("How many levels do you want your cache to be?: \n");
        if (fgets(input, inputSize, stdin) == NULL)
        {
            printf(">>> Failed to read Inclusion Policy\n");
        }

        // convert input string to int
        NUM_OF_CACHE_LEVELS = atoi(input);

        // safeguard for bad input
        if (NUM_OF_CACHE_LEVELS >= 1)
        {
            break;
        }
        else
        {
            printf(">>> Invalid selection, must be equal to or greater than 1\n");
        }
    }

    // create MAIN_CACHE
    MAIN_CACHE = malloc(NUM_OF_CACHE_LEVELS * sizeof(CacheLevel *));

    for (int i = 0; i < NUM_OF_CACHE_LEVELS; i++)
    {
        CacheLevel *newCacheLevel = getCacheLevel(i + 1);
        if (newCacheLevel == NULL) 
        {
            // free cache since there was an error
            free(MAIN_CACHE);
            return -1;
        }

        MAIN_CACHE[i] = newCacheLevel;
    }

    // return zero if everything went well
    return 0;
}

CacheLevel *getCacheLevel(int level)
{
    int inputSize = 256;
    char input[inputSize];

    int cacheSize = -1;
    int associativity = -1;
    int sets = -1;

    // CACHE SIZE
    while (true)
    {
        printf("Cache Size for level %d: \n", level);
        if (fgets(input, inputSize, stdin) == NULL)
        {
            printf(">>> Failed to read Cache Size\n");
        }

        // convert input string to int
        cacheSize = atoi(input);

        // safeguard for bad input
        if (cacheSize <= 0)
        {
            printf(">>> Must be a positive integer greater than 1\n");
        }
        else if (!isPowerOfTwo(cacheSize))
        {
            printf(">>> Must be a power of 2\n");
        }
        else
        {
            break;
        }
    }
    // Associativity
    while (true)
    {
        printf("Associativity for level %d: \n", level);
        if (fgets(input, inputSize, stdin) == NULL)
        {
            printf(">>> Failed to read Associativity\n");
        }

        // convert input string to int
        associativity = atoi(input);

        // safeguard for bad input
        if (associativity <= 0)
        {
            printf(">>> Must be a positive integer greater than 1\n");
        }
        else if (!isPowerOfTwo(associativity))
        {
            printf(">>> Must be a power of 2\n");
        }
        else
        {
            break;
        }
    }

    // calculate sets
    sets = cacheSize / (associativity * BLOCK_SIZE);
    if (sets <= 0)
    {
        printf(">>> Invalid input for Set calculations with: \nCache Size and/or\nBlock Size and/or\nAssociativity\n");
        printf(">>> Cache Size must be greater than or equal \n    to the product of Associativity and Block Size\n");
        printf(">>> Please re-enter the following values:\n");

        // return null to signify error with input and sets not makeing sense
        return NULL;
    }

    // create cache
    CacheLevel *cache = malloc(sizeof(CacheLevel));
    cache = createCacheLevel(level, cacheSize, associativity, sets);
    return cache;
}

// A utility function to create a cache level
CacheLevel *createCacheLevel(int level, int cacheSize, int associativity, int numSets)
{
    CacheLevel *cache = (CacheLevel *)malloc(sizeof(CacheLevel));
    cache->level = level;
    cache->cacheSize = cacheSize;
    cache->associativity = associativity;
    cache->sets = numSets;
    return cache;
}

void printInputs(char *traceFile)
{
    printf("===== Simulator configuration =====\n");
    // Block size
    printf("BLOCKSIZE:\t\t%d\n", BLOCK_SIZE);

    // Cache specific prints
    for (int i = 0; i < NUM_OF_CACHE_LEVELS; i++)
    {
        printf("L%d_SIZE:\t\t%d\n", MAIN_CACHE[i]->level, MAIN_CACHE[i]->cacheSize);
        printf("L%d_ASSOC:\t\t%d\n", MAIN_CACHE[i]->level, MAIN_CACHE[i]->associativity);
    }

    // Replacement Policy
    if (REPLACEMENT_POLICY == 1)
    {
        printf("REPLACEMENT POLICY:\tLRU\n");
    }
    else if (REPLACEMENT_POLICY == 2)
    {
        printf("REPLACEMENT POLICY:\tFIFO\n");
    }
    else if (REPLACEMENT_POLICY == 3)
    {
        printf("REPLACEMENT POLICY:\tOptimal\n");
    }

    // Inclusion Policy
    if (INCLUSION_POLICY == 1)
    {
        printf("INCLUSION PROPERTY:\tInclusive\n");
    }
    else if (INCLUSION_POLICY == 2)
    {
        printf("INCLUSION PROPERTY:\tExclusive\n");
    }
    else if (INCLUSION_POLICY == 3)
    {
        printf("INCLUSION PROPERTY:\tNon-inclusive\n");
    }
    
    // Trace File
    printf("trace_file:\t\t%s\n", traceFile);

    printf("----------------------------------------\n");
}

void printCache()
{
    // print the main cache to check if it works
    for (int i = 0; i < NUM_OF_CACHE_LEVELS; i++)
    {
        printf("Level: %d, Cache Size: %d, Associativity: %d, Sets: %d\n", 
            MAIN_CACHE[i]->level, 
            MAIN_CACHE[i]->cacheSize, 
            MAIN_CACHE[i]->associativity, 
            MAIN_CACHE[i]->sets);
    }
}