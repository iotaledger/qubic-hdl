set_global_assignment -entity "PLL_0" -library "lib_PLL_0" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "PLL_0" -library "lib_PLL_0" -name IP_TOOL_VERSION "18.1"
set_global_assignment -entity "PLL_0" -library "lib_PLL_0" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_PLL_0" -name SPD_FILE [file join $::quartus(sip_path) "PLL_0.spd"]

set_global_assignment -library "lib_PLL_0" -name MISC_FILE [file join $::quartus(sip_path) "PLL_0_sim/PLL_0.vo"]
