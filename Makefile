SRC_DIR = ../../src
SRC_FILES = $(addprefix $(SRC_DIR)/, \
   fp16_int4_mul.v \
   dw_mul.v \
)


#BEHAV_FILES = $(addprefix $(BEHAV_FILES_DIR)/, \
         *.v \
)


SIM_DIR = ../../verification/tb
SIM_FILES = $(addprefix $(SIM_DIR)/, \
   tb_fp16_int4_mul.v \
)

TB_SCRIPT_DIR = verification/scripts
TB_SCRIPT_FILES = $(addprefix $(TB_SCRIPT_DIR)/, \
   tb_TensorPE_float.py \
)

HEX_DIR = ../../verification/hex
HEX_FILES = $(addprefix $(HEX_DIR)/, \
   din_X.hex \
   din_W.hex \
   din_Y.hex \
   dout.hex \
)

#BEHAV_DIR = ../../verification/behav
#tb_BF16_PE.v 
SYN_DIR = ../../syn
SYN_FILES = $(addprefix $(SYN_DIR)/, \
   top.syn.tcl \
)

RUN_DIR = ./output

PE_RUN_DIR = ${RUN_DIR}/pe
DMA_RUN_DIR = ${RUN_DIR}/dma

SYNOPSYS = /ids/tools/SYNOPSYS/syn/S-2021.06-SP4



VV         = vcs
#VVOPTS     = -o simv -full64 -kdb -debug_access+all
VVOPTS     = -o simv -full64 -kdb -debug_access+all +incdir+$(SYNOPSYS)/dw/sim_ver -y $(SYNOPSYS)/dw/sim_ver/*.v

nWave      = nWave


Verdi = Verdi
VerdiOPTS = ""

DC = dc_shell-xg-t -64bit
DCOPTS = ""

#${PE_RUN_DIR}/simv: clean
#   mkdir -p ${PE_RUN_DIR}
#   cd ${PE_RUN_DIR}/ && $(VV) $(VVOPTS) $(SRC_FILES) $(BEHAV_FILES) $(SIM_FILES);
#   ./$@;

${PE_RUN_DIR}/simv: clean
   mkdir -p ${PE_RUN_DIR}
#   python ${TB_SCRIPT_FILES}
   cd ${PE_RUN_DIR} && $(VV) $(VVOPTS) $(SRC_FILES) $(SIM_FILES) $(BEHAV_FILES);
   ./$@;

${PE_RUN_DIR}/waveform: ${PE_RUN_DIR}/simv
   cd ${PE_RUN_DIR} && ${nWave} output.fsdb

${PE_RUN_DIR}/verdi: #${PE_RUN_DIR}/simv
   cd ${PE_RUN_DIR} && ${Verdi} $(SRC_FILES) $(BEHAV_FILES) $(SIM_FILES);

${PE_RUN_DIR}/syn:
   mkdir -p ${PE_RUN_DIR}
   cd ${PE_RUN_DIR} && ${DC} -f $(SYN_FILES) $(BEHAV_FILES);
#rm -rf *.log;

clean:
   rm -rf ${RUN_DIR}/*

gitpush:
   git add .
   git commit -m "update"
   git push