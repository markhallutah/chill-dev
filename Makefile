
.SUFFIXES:
.PHONY: all depend depend-cuda-chill clean veryclean cuda-chill
.PHONY: chill 

CC = g++
CFLAGS = -g -Wno-write-strings
DEPENDENCE_CFLAGS = -M
#OMEGAHOME = $(HOME)/omega

ifdef TEST_COVERAGE
  CFLAGS := $(CFLAGS) -fprofile-arcs -ftest-coverage
endif

# TODO   auto-generate using config.h generated by autoconf?
CHILLVERSION = "\"0.2.0\""
PYTHON=python  #=$(shell `which python` ) 
PYVERSION=$(shell $(PYTHON) -c "import sys; print(sys.version[:3])")  # 2.6
PYTHONVER = python$(PYVERSION)
PYTHONINCLUDE = $(shell $(PYTHON) -c "from distutils import sysconfig; print(sysconfig.get_python_inc())")
PYTHONLIBDIR  = $(shell $(PYTHON) -c "from distutils import sysconfig; print(sysconfig.get_config_var('LIBDIR'))")
PYTHONCONFIG  = $(shell $(PYTHON) -c "from distutils import sysconfig; print(sysconfig.get_config_var('LIBPL'))")
# SCRIPT_LANG = lua <-- supplied by the command line


# this creates a LUAHOME even if you don't have such a directory
ifeq ($(strip $(wildcard $(LUAHOME))),)
LUAHOME = $(HOME)/lua
endif
LUA_PATH = -L${LUAHOME}/lib


# where do include files live
INC_PATH = -I${PYTHONINCLUDE} -I${OMEGAHOME}/include -I${LUAHOME}/include

# where do libraries live
LIB_PATH = -L${OMEGAHOME}/code_gen/obj -L${OMEGAHOME}/omega_lib/obj 
# seemingly not needed -L${PYTHONCONFIG}



CORE_LIBS = -lm -lcodegen -lomega
RUNNER_LIBS = -llua -ldl -lreadline -lhistory -lpthread -ldl -lutil -lm -l${PYTHONVER}

TDLHOME = ${ROSEHOME}/libltdl

BOOST_DATE_TIME_LIB = -lboost_date_time
BOOST_FILESYSTEM_LIB = -lboost_filesystem
BOOST_LDFLAGS = -L${BOOSTHOME}/lib
BOOST_PROGRAM_OPTIONS_LIB = -lboost_program_options
BOOST_REGEX_LIB = -lboost_regex
BOOST_SYSTEM_LIB = -lboost_system
BOOST_THREAD_LIB = -lboost_thread
BOOST_WAVE_LIB = -lboost_wave

ROSE_LIBS =  -lrose  $(BOOST_LDFLAGS) $(BOOST_DATE_TIME_LIB)\
             $(BOOST_THREAD_LIB) $(BOOST_FILESYSTEM_LIB) $(BOOST_PROGRAM_OPTIONS_LIB)\
             $(BOOST_REGEX_LIB)  $(BOOST_SYSTEM_LIB) $(BOOST_SERIALIZATION_LIB)  \
             $(BOOST_WAVE_LIB) -lrt -ldl


# Source files common to both chill and cuda-chill
CORE_SRCS = dep.cc omegatools.cc irtools.cc loop.cc loop_basic.cc loop_datacopy.cc loop_unroll.cc loop_tile.cc loop_extra.cc
LIB_SRCS = $(CORE_SRCS)

# files that will be generated by bison, flex, and make that need to be removed at clean.
GENERATED_SRCS = parser.tab.hh parser.tab.cc parse_expr.yy.cc parse_expr.ll.hh parse_expr.tab.cc parse_expr.tab.hh Makefile.deps 
# object files that are specific to lua or python builds. -- This is used so that SCRIPT_LANG does not need to be specified during clean
ORPHAN_OBJS = chill_run_util.o chillmodule.o parse_expr.tab.o parse_expr.yy.o

# files used in chill and cuda-chill interfaces
ifeq ($(SCRIPT_LANG),lua)
  RUNNER_SRCS = chill_run.cc chill_env.cc
else
  ifeq ($(SCRIPT_LANG),python)
    RUNNER_SRCS = chill_run.cc chillmodule.cc
  else
    RUNNER_SRCS = chill_run.cc chill_env.cc
  endif
endif

# files used in chill but not cuda-chill
IR_CHILL_SRCS = ir_rose.cc ir_rose_utils.cc
ifeq ($(SCRIPT_LANG),lua)
  YACC_SRCS = parse_expr.yy.cc parse_expr.tab.cc
  CHILL_RUNNER_SRCS = chill_run_util.cc
  CHILL_SRCS = $(CORE_SRCS) $(IR_CHILL_SRCS) $(CHILL_RUNNER_SRCS) $(RUNNER_SRCS)
else
  ifeq ($(SCRIPT_LANG),python)
    YACC_SRCS = parse_expr.yy.cc parse_expr.tab.cc
    CHILL_RUNNER_SRCS = chill_run_util.cc
    CHILL_SRCS = $(CORE_SRCS) $(IR_CHILL_SRCS) $(CHILL_RUNNER_SRCS) $(RUNNER_SRCS)
  else
    YACC_SRCS = lex.yy.cc parser.tab.cc
    CHILL_RUNNER_SRCS = 
    CHILL_SRCS = $(CORE_SRCS) $(IR_CHILL_SRCS) $(YACC_SRCS) $(RUNNER_SRCS)
  endif
endif

# source files for cuda-chill but not chill
CUDACHILL_ONLY_SRCS = mem_mapping_utils.cc loop_cuda_rose.cc
IR_CUDACHILL_SRCS = ir_rose.cc ir_rose_utils.cc ir_cudarose.cc ir_cuda_rose_utils.cc
CUDACHILL_RUNNER_SRCS =
CUDACHILL_SRCS = $(CORE_SRCS) $(CUDACHILL_ONLY_SRCS) $(IR_CUDACHILL_SRCS) $(RUNNER_SRCS) $(CUDACHILL_RUNNER_SRCS)

# set interface language flags
ifeq ($(SCRIPT_LANG),lua)
  RUNNER_EXTRA_CFLAGS = -DLUA
else
  ifeq ($(SCRIPT_LANG),python)
    RUNNER_EXTRA_CFLAGS = -DPYTHON
  endif
endif

depend-cuda-chill: CFLAGS := $(CFLAGS) -DCUDACHILL
cuda-chill: CFLAGS := $(CFLAGS) -DCUDACHILL

ALL_SRCS = $(CORE_SRCS) $(YACC_SRCS) $(IR_CHILL_SRCS) $(CUDACHILL_ONLY_SRCS) $(IR_CUDACHILL_SRCS) $(RUNNER_SRCS) $(CHILL_RUNNER_SRCS) $(CUDACHILL_RUNNER_SRCS)
ALL_OBJS = $(ALL_SRCS:.cc=.o) $(ORPHAN_OBJS)

RUNNER_DEFINES = -DLUA_USE_LINUX -DCHILL_BUILD_VERSION=$(CHILLVERSION) -DCHILL_BUILD_DATE="\"$(CHILL_BUILD_DATE)\""


YACC_EXTRA_CFLAGS =

#####################################################################
# compiler intermediate code specific definitions
#####################################################################



#LIBS := $(LIBS) $(ROSE_LIBS)
LIB_PATH := $(LIB_PATH) -L${ROSEHOME}/lib -L${TDLHOME}
#LIB_SRCS := $(LIB_SRCS) #  $(IR_SRCS)
INC_PATH := $(INC_PATH) -I${ROSEHOME}/include -I${BOOSTHOME}/include
YACC_EXTRA_CFLAGS := -DBUILD_ROSE
RUNNER_EXTRA_CFLAGS := $(RUNNER_EXTRA_CFLAGS) -DBUILD_ROSE


#####################################################################
# build rules
#####################################################################

YACC_OBJS = $(YACC_SRCS:.cc=.o)
RUNNER_OBJS = $(RUNNER_SRCS:.cc=.o)
CHILL_RUNNER_OBJS = $(CHILL_RUNNER_SRCS:.cc=.o)
CUDACHILL_RUNNER_OBJS = $(CUDACHILL_RUNNER_SRCS:.cc=.o)
LIB_OBJS = $(LIB_SRCS:.cc=.o)
IR_CHILL_OBJS = $(IR_CHILL_SRCS:.cc=.o) 
IR_CUDACHILL_OBJS = $(IR_CUDACHILL_SRCS:.cc=.o) 
CUDACHILL_ONLY_OBJS = $(CUDACHILL_ONLY_SRCS:.cc=.o)

CHILL_OBJS     = $(CHILL_SRCS:.cc=.o)
CUDACHILL_OBJS = $(CUDACHILL_SRCS:.cc=.o)


all: cuda-chill chill 


# can't these be combined to a superset of all source files?
depend: depend-cuda-chill

depend-chill: $(LIB_SRCS) $(RUNNER_SRCS) $(CHILL_RUNNER_SRCS) $(YACC_SRCS)
	$(CC) $(DEPENDENCE_CFLAGS) $(INC_PATH) $(LIB_SRCS) $(RUNNER_SRCS) $(CHILL_RUNNER_SRCS) $(YACC_SRCS) > Makefile.deps

depend-cuda-chill: $(LIB_SRCS) $(RUNNER_SRCS) $(CUDACHILL_RUNNER_SRCS)
	$(CC) $(DEPENDENCE_CFLAGS) $(INC_PATH) $(LIB_SRCS) $(RUNNER_SRCS) $(CUDACHILL_RUNNER_SRCS) > Makefile.deps

libchill_xform.a: $(LIB_OBJS) $(IR_CHILL_OBJS)
	ar -rs $@ $(LIB_OBJS) $(IR_CHILL_OBJS)

libcudachill_xform.a: $(LIB_OBJS) $(IR_CUDACHILL_OBJS) $(CUDACHILL_ONLY_OBJS)
	ar -rs $@ $(LIB_OBJS) $(IR_CUDACHILL_OBJS) $(CUDACHILL_ONLY_OBJS)

%.o: %.cc
	$(CC) $(CFLAGS) $(INC_PATH) $< -c -o $@


clean:
	@rm -fr $(ALL_OBJS) $(YACC_SRCS) $(GENERATED_SRCS)

veryclean:
	@rm -fr $(ALL_OBJS) $(YACC_SRCS) libchill_xform.a libcudachill_xform.a chill cuda-chill


cuda-chill: libcudachill_xform.a $(CUDACHILL_RUNNER_OBJS) $(RUNNER_OBJS)
	$(CC) $(CFLAGS) $(LIB_PATH) $(LUA_PATH) $(CUDACHILL_RUNNER_OBJS) $(RUNNER_OBJS) $< $(CORE_LIBS) $(ROSE_LIBS) $(RUNNER_LIBS) -o $@

ifeq ($(SCRIPT_LANG),lua)
chill: libchill_xform.a $(CHILL_RUNNER_OBJS) $(RUNNER_OBJS) $(YACC_OBJS)
	$(CC) $(CFLAGS) $(LIB_PATH) $(LUA_PATH) $(YACC_OBJS) $(CHILL_RUNNER_OBJS) $(RUNNER_OBJS) $< $(CORE_LIBS)  $(ROSE_LIBS) $(RUNNER_LIBS) -o $@
else
ifeq ($(SCRIPT_LANG),python)
chill: libchill_xform.a $(CHILL_RUNNER_OBJS) $(RUNNER_OBJS) $(YACC_OBJS)
	$(CC) $(CFLAGS) $(LIB_PATH) $(YACC_OBJS) $(CHILL_RUNNER_OBJS) $(RUNNER_OBJS) $< $(CORE_LIBS) $(ROSE_LIBS) $(RUNNER_LIBS) -o $@

else
chill: libchill_xform.a $(YACC_OBJS)
	$(CC) $(CFLAGS) $(LIB_PATH) $(YACC_OBJS) $< $(CORE_LIBS)  $(ROSE_LIBS) -o $@
endif
endif


lex.yy.cc: parser.ll parser.tab.hh
	flex++ parser.ll

lex.yy.o: lex.yy.cc
	$(CC) $(CFLAGS) -c $< -o $@

parser.tab.hh parser.tab.cc: parser.yy
	bison -t -d $<

parser.tab.o: parser.tab.cc
	$(CC) $(CFLAGS) $(YACC_EXTRA_CFLAGS) $(INC_PATH) -DCHILL_BUILD_DATE="\"$(CHILL_BUILD_DATE)\"" -c $< -o $@


parse_expr.tab.cc: parse_expr.yy
	bison -t -d parse_expr.yy

parse_expr.tab.o: parse_expr.tab.cc
	$(CC) $(CFLAGS) $(YACC_CFLAGS) $(INC_PATH) -o $@ -c parse_expr.tab.cc

parse_expr.yy.cc: parse_expr.tab.cc parse_expr.ll
	flex -o parse_expr.yy.cc parse_expr.ll

parse_expr.yy.o: parse_expr.yy.cc
	$(CC) $(CFLAGS) $(YACC_CFLAGS) $(INC_PATH) -o $@ -c parse_expr.yy.cc

$(RUNNER_SRCS:.cc=.o): %.o: %.cc
	$(CC) $(CFLAGS) $(RUNNER_EXTRA_CFLAGS) $(INC_PATH) $(RUNNER_DEFINES) $< -c -o $@

$(CHILL_RUNNER_SRCS:.cc=.o): %.o: %.cc
	$(CC) $(CFLAGS) $(RUNNER_EXTRA_CFLAGS) $(INC_PATH) $(RUNNER_DEFINES) $< -c -o $@

$(CUDACHILL_RUNNER_SRCS:.cc=.o): %.o %.cc
	$(CC) $(CFLAGS) $(RUNNER_EXTRA_CFLAGS) $(INC_PATH) $(RUNNER_DEFINES) $< -c -o $@


$(IR_SRCS:.cc=.o): %.o: %.cc
	$(CC) -Wno-write-strings $(CFLAGS) $(INC_PATH) $< -c -o $@

ifeq ($(shell test -f Makefile.deps && echo "true"), true)
include Makefile.deps
endif

CHILL_BUILD_DATE = $(shell date +%m/%d/%Y)
