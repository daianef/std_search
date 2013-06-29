##############################################################
##         Initial Encounter Configuration                  ##
## Script Generated for Undergrad class of microelectronics ##
## Generated by Matheus Moreira - 9/11/2011                 ##
## GAPH/FACIN/PUCRS                                         ##
##                                                          ##
## Functionalities of this script:                          ##
##  -Add filler cells to the design                         ##
##  -Generate a summary report of the final design          ##
##############################################################
##Add filler cells
getFillerMode -quiet
addFiller -cell HS65_GS_FILLERPFP4 HS65_GS_FILLERPFP3 HS65_GS_FILLERPFP2 HS65_GS_FILLERPFP1 -prefix FILLER
##Generate reports
summaryReport -outdir summaryReport