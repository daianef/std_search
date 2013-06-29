##############################################################
##         Logical / Physical synthesis constraints         ##
## Script Generated for Undergrad class of microelectronics ##
## Generated by Matheus Moreira - 9/11/2011                 ##
## GAPH/FACIN/PUCRS                                         ##
##############################################################

## DEFINE VARS
set sdc_version 1.5
set_load_unit -picofarads 1

## INPUTS

set_input_transition -min -rise 0.003 [get_ports A*]
set_input_transition -max -rise 0.16 [get_ports A*]
set_input_transition -min -fall 0.003 [get_ports A*]
set_input_transition -max -fall 0.16 [get_ports A*]

set_input_transition -min -rise 0.003 [get_ports B*]
set_input_transition -max -rise 0.16 [get_ports B*]
set_input_transition -min -fall 0.003 [get_ports B*]
set_input_transition -max -fall 0.16 [get_ports B*]

## OUTPUTS

set_load -min 0.0014 [all_outputs]
set_load -max 0.32 [all_outputs]
