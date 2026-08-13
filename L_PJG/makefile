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

#clean some file
clean:
	rm -rf ${OUTPUT_DIR}
