.PHONY:com cov clean debug sim saif

TEST_ITER_NUM := 5
OUTPUT = vcs_top_iter_${TEST_ITER_NUM}_pre_sdf
OUTPUT_DIR = ${OUTPUT}

SIM_FILE = sim_rtl.f
TOP_MODULE = tb_detector
OUTPUT_FILE_NAME = $(OUTPUT)
FSDB_FILE = $(OUTPUT_FILE_NAME:%=%.fsdb)
SAIF_FILE = $(OUTPUT_FILE_NAME:%=%.saif)

#compile command
VCS = vcs -sverilog +v2k -timescale=1ns/1ns \
	-top ${TOP_MODULE} \
	+define+RTLVCD  \
	-debug_all			    \
	+memcbk \
	+notimingcheck			    \
	-fsdb \
	+vcs+flush+all \
	+vcs+dumparrays \
	-parallel+saif \
	+define+OUTPUT_FILE_NAME=\"${OUTPUT_FILE_NAME}\" \
	+define+TEST_ITER_NUM=${TEST_ITER_NUM} \
	-full64 \
	-j16 \
	-ignore all \
	-o ${OUTPUT}                        \
	-l compile.log                      \

#simulation command
SIM = ./${OUTPUT} -l sim.log  +fsdb+autoflush +fsdb+compress +fsdb+mda+region=0.5GB

#start compile
com:
	mkdir -p ${OUTPUT_DIR}
	cd ${OUTPUT_DIR} && ${VCS} -f ../${SIM_FILE} 

#start simulation
sim: com
	cd ${OUTPUT_DIR} && ${SIM}

#show the coverage
cov:
	dve -covdir *vdb &

#start debug commnd
debug:
	dve -vpd ${output}.vpd &

saif: sim
	fsdb2saif ${OUTPUT_DIR}/${FSDB_FILE} -o ${OUTPUT_DIR}/${SAIF_FILE}

# =============================================================================
# Functional, self-checking simulation target (golden-based, bit-exact check)
# Top: tb_fc_detector (rtl/testbench_fc.sv). Golden x_p8.txt corresponds to
# iter=16 sweeps, so TEST_ITER_NUM is fixed to 16 here.
#   make com-fc   -> compile only (output dir: vcs_top_fc_iter16)
#   make sim-fc   -> compile + run  (prints FC: PASS / FC: FAIL)
# =============================================================================
FC_TEST_ITER_NUM := 16
FC_OUTPUT       = vcs_top_fc_${FC_TEST_ITER_NUM}_pre_sdf
FC_OUTPUT_DIR   = ${FC_OUTPUT}
FC_SIM_FILE     = sim_rtl_fc.f
FC_TOP_MODULE   = tb_fc_detector

FC_VCS = vcs -sverilog +v2k -timescale=1ns/1ns \
	-top ${FC_TOP_MODULE} \
	+define+RTLVCD  \
	-debug_all			    \
	+memcbk \
	+notimingcheck			    \
	-fsdb \
	+vcs+flush+all \
	+define+TEST_ITER_NUM=${FC_TEST_ITER_NUM} \
	-full64 \
	-j16 \
	-ignore all \
	-o ${FC_OUTPUT}                        \
	-l compile.log                        \

FC_SIM = ./${FC_OUTPUT} -l sim.log

com-fc:
	mkdir -p ${FC_OUTPUT_DIR}
	cd ${FC_OUTPUT_DIR} && ${FC_VCS} -f ../${FC_SIM_FILE}

sim-fc: com-fc
	cd ${FC_OUTPUT_DIR} && ${FC_SIM}

clean-fc:
	rm -rf ${FC_OUTPUT_DIR}

.PHONY: com-fc sim-fc clean-fc

#clean some file
clean:
	rm -rf ${OUTPUT_DIR} ${FC_OUTPUT_DIR}
