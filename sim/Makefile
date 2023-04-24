CC = gcc
OPT = -O3
#OPT = -g
WARN = -Wall
CFLAGS = $(OPT) $(WARN) $(INC) $(LIB)

# List all your .cc files here (source files, excluding header files)
SIM_SRC = cacheSim.c ourHeaders.c

# List corresponding compiled object files here (.o files)
SIM_OBJ = cacheSim.o ourHeaders.o
 
#################################

# default rule

all: cacheSim
	@echo "my work is done here..."


# rule for making cacheSim

cacheSim: $(SIM_OBJ)
	$(CC) -o cacheSim $(CFLAGS) $(SIM_OBJ) -lm
	@echo "-----------DONE WITH SIM_CACHE-----------"


# generic rule for converting any .cc file to any .o file
 
.cc.o:
	$(CC) $(CFLAGS)  -c $*.cc


# type "make clean" to remove all .o files plus the cacheSim binary

clean:
	rm -f *.o cacheSim


# type "make clobber" to remove all .o files (leaves cacheSim binary)

clobber:
	rm -f *.o


