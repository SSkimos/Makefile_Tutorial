CC = gcc

WARNING    = -Wall -Werror -Wextra # :)
CFLAGS     = -std=c11 -pedantic $(WARNING) # -pedantic flag will enforce us to use -std=c11
LFLAGS    ?= $(shell pkg-config --cflags --libs check)
INC_CHECK ?= $(shell pkg-config --cflags check) # pkg-config will help us with crossplatform building

SRC_DIR  = .
SRC     := $(shell find $(SRC_DIR) -name "s21*.c" | sed -e 's/\.\///')

TEST_DIR    = tests
TEST       := $(shell find $(TEST_DIR) -name "*.c" | sed -e 's/\.\///')
TEST_FLAGS := --coverage -c -g  # something we need to make sure code with check.h will be built properly
INC_DIRS   := $(shell find $(SRC_DIR) -type d)
INC_FLAGS  := $(addprefix -I, $(INC_DIRS))

BUILD_DIR       = obj
BUILD_TEST_DIR  = obj_test
GCOV_OBJ_DIR   := gcov_res

OBJS      := $(SRC:%.c=$(BUILD_DIR)/%.o)
TEST_OBJS := $(TEST:%.c=$(BUILD_TEST_DIR)/%.o)
GCOV_OBJS := $(SRC:%.c=$(GCOV_OBJ_DIR)/%.o)

DEC_TEST :=	# Enter your main test file.c
LIB      :=	# Enter your library.a name


all: $(LIB) test

test: test.out
	./test.out

test.out: $(LIB) $(TEST_OBJS) $(BUILD_TEST_DIR)/main.o
	$(CC) $(LFLAGS) $(TEST_OBJS) $(BUILD_TEST_DIR)/main.o $(LIB) -o test.out

$(LIB): $(OBJS)
	@mkdir -p $(BUILD_DIR)
	ar rc $(LIB) $(OBJS)
	ranlib $(LIB)

gcov_report: $(TEST_OBJS) $(GCOV_OBJS) $(BUILD_TEST_DIR)/main.o $(SRC)
	@mkdir -p $(GCOV_OBJ_DIR)
	ar rc $(LIB) $(GCOV_OBJS)
	ranlib $(LIB)
	$(CC) $(LFLAGS) --coverage $(TEST_OBJS) $(BUILD_TEST_DIR)/main.o $(LIB) -o test.out
	- ./test.out
	# gcov_report target relies on our lcov based in ../materials folder
	# we have to place lcov in mateirals folder to make sure gcov_report target will build no matter what
	./../materials/lcov/bin/lcov -f -c --directory . -o ./gcov_res/coverage.info 
	./../materials/lcov/bin/genhtml gcov_res/coverage.info --output-directory=gcov_res
	open gcov_res/index.html

# this pattern rule will build *.o files out of *.c files and store them in BUILD_DIR/.o dir
$(BUILD_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

# this will build and link main test.c with test_suites.c
$(BUILD_TEST_DIR)/main.o: $(DEC_TEST) 
	@mkdir -p $(BUILD_TEST_DIR)
	$(CC) $(INC_CHECK) -c -o $(BUILD_TEST_DIR)/main.o $(DEC_TEST)

$(BUILD_TEST_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(INC_CHECK) -c $^ -o $@

$(GCOV_OBJ_DIR)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(TEST_FLAGS) -c $< -o $@

.PHONY: clean rebuild lint test

# we are cleaning everything we have built
clean: 
	rm -f *.gcda *.gcov *.o *.gcno
	rm -f $(LIB)
	rm -rf $(BUILD_DIR)
	rm -rf $(BUILD_TEST_DIR)
	rm -rf $(GCOV_OBJ_DIR)
	rm -f test.out

rebuild: clean all

# these targets will help us test our code
# cpplint (probably will be other script in October 2022), cppcheck and leaks
leaks: test.out
	-leaks -atExit -- ./test.out 

lint:
	-cp ../materials/linters/CPPLINT.cfg .
	-find . -type f -name "*.c" | xargs python3 ../materials/linters/cpplint.py --extensions=c
	-find . -type f -name "*.h" | xargs python3 ../materials/linters/cpplint.py --extensions=c
	-find . -type f -name "*.c" | xargs cppcheck --enable=all --suppress=missingIncludeSystem
	rm -f CPPLINT.cfg
