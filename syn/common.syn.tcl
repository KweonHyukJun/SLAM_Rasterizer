# common.tcl setup library files

# Set library paths
# set STDCELL "/ids/kits/UMC28_Kit/v-logic_um28nchslogl30hdh140f/DesignWare_logic_libs/umc28nllh/30hd/hdh/svt/latest/liberty/ccs"

set STDCELL "/ids/kits/UMC28_Kit/v-logic_um28nchslogl30hdh140f/DesignWare_logic_libs/umc28nllh/30hd/hdh/svt/1.02a/liberty/ccs"

set DC_HOME [get_unix_variable DC_HOME]
#/ids/tools/SYNOPSYS/syn/S-2021.06-SP4/
set search_path [list "." $STDCELL ${DC_HOME}/libraries/syn]
set link_library "* um28nchslogl30hdh140f_tt0p9v25c.db dw_foundation.sldb gtech.db standard.sldb"
set target_library "um28nchslogl30hdh140f_tt0p9v25c.db"

# Don't use scan, ECO, and clock-related cells and latches during synthesis
#set_dont_use { tcbn40lpbwp12t50m1ptc_ccs/L* tcbn40lpbwp12t50m1ptc_ccs/S* tcbn40lpbwp12t50m1ptc_ccs/G* tcbn40lpbwp12t50m1ptc_ccs/CK*}

# set_dont_use any *XL* cell
# set_dont_use { tcbn65lptc/L* tcbn65lptc/S* tcbn65lptc/G* tcbn65lptc/CK*}

