
# use this file to define global variables on module scope
# or perform other initialization procedures.
# this file will not be touched when new functions are exported to
# this module.


Write-Host -ForegroundColor Yellow @"
##########################################################################
#                                                                        #
#     )  (                     (        )                             )  #
#  ( /(  )\ )  *   )    (      )\ )  ( /(    (                  )  ( /(  #
#  )\())(()/(` )  /(    )\    (()/(  )\())   )\ )       )    ( /(  )\())  #
# ((_)\  /(_))( )(_))((((_)(   /(_))((_)\   (()/(      (     )\())((_)\  #
# __((_)(_)) (_(_())  )\ _ )\ (_))    ((_)   /(_))_    )\  '((_)\  _((_) #
# \ \/ /|_ _||_   _|  (_)_\(_)/ __|  / _ \  (_)) __| _((_)) | |(_)| || | #
#  >  <  | |   | |     / _ \  \__ \ | (_) |   | (_ || '  \()| '_ \| __ | #
# /_/\_\|___|  |_|    /_/ \_\ |___/  \___/     \___||_|_|_| |_.__/|_||_| #
#                                                                        #
##########################################################################


Author:          Markus Hupfauer
Copyright:       XITASO GmbH
License:         MIT License (see license.txt)
Mail (private):  markushupfauer@ieee.org
Mail (business): markus.hupfauer@xitaso.com
Website:         https://xitaso.com
Version:         0.9.4


"@

Write-Host -ForegroundColor Red "IMPORTANT: You have to call Start-MigrationEnv before anything else"
