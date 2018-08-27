#!/usr/bin/env bash

# 2018-07-05 - Created by TGarbin

# This script modifies the management account addressing [PI-005185]
# and [PI-002119]
# Hide and move management home folder
# Created to address: Management accounts created with DEP may contain
# differences in the account settings due to variables in the
# environment or workflow during account creation.
# https://www.jamf.com/jamf-nation/discussions/26881\
# /dep-management-account-hidden

# Update with your desired variables
managementUser=''
wrongDir="/Users/$managementUser"
rightDir="/private/var/$managementUser"
dsclDir="/Local/Default/Users/$managementUser"
correctID=80
noUserExists='<dscl_cmd> DS Error: -14136 (eDSRecordNotFound)'

# file logging
write_log(){
   printf "%s\n" "$(date "+%Y-%m-%d %H:%M:%S") $(basename "$0") - ${1}"
}

checkTest() {
check=$1
cmdRun=$2
if [[ "$check" -gt 0 ]]; then
   write_log "Error: $cmdRun"
   exit 1
else
   write_log "Info: Success"
fi
}

write_log "Start"

# Does this user exist?
dsclHomeDir="$(dscl localhost read "$dsclDir" \
NFSHomeDirectory 2>&1)"
if [[ "$dsclHomeDir" == *"$noUserExists" ]]; then
   write_log "Error: User does not exist, exiting"
   exit 1
fi

# If the user folder is not in /var/ fix it
if [[ -d "$wrongDir" ]]; then
   moveDir="$(mv "$wrongDir" "$rightDir" 2>&1)"
   if [[ "$?" -gt 0 ]]; then
      write_log "Error: ${moveDir}"
      exit 1
   else
      write_log "Info: Dir is correctly located at $rightDir"
   fi
   write_log "Info: Dir correctly located at $rightDir"
fi

# If dscl home dir is not in /var/ fix it
dsclHomeDir="$(dscl localhost read "$dsclDir" \
NFSHomeDirectory | awk '{print $2}' 2>&1)"
if [[ "$dsclHomeDir" == "$wrongDir" ]]; then
   dsclfixDir="$(dscl localhost change "$dsclDir" \
   NFSHomeDirectory "$wrongDir" "$rightDir" 2>&1)"
   if [[ "$?" -gt 0 ]]; then
      write_log "Error: ${dsclfixDir}"
      exit 1
   else
      dsclHomeDir="$(dscl localhost read "$dsclDir" \
      NFSHomeDirectory | awk '{print $2}' 2>&1)"
      write_log "Info: dscl Directory is $dsclHomeDir"
   fi
else
   dsclHomeDir="$(dscl localhost read "$dsclDir" \
   NFSHomeDirectory | awk '{print $2}' 2>&1)"
   write_log "Info: dscl Directory is $dsclHomeDir"
fi

# If dscl uniqueID is not 80, make it so
dsclIdCheck="$(dscl localhost read "$dsclDir" \
UniqueID | awk '{print $2}' 2>&1)"
if [[ "${dsclIdCheck}" != "$correctID" ]]; then
   dsclIdfix="$(dscl localhost create "$dsclDir" \
   UniqueID "${dsclIdCheck}" "$correctID" 2>&1)"
   if [[ "$?" -gt 0 ]]; then
      write_log "Error: ${dsclIdfix}"
      exit 1
   else
      write_log "Info: dscl uniqueID is correct: $correctID"
   fi
else
   write_log "Info: dscl uniqueID is correct: $correctID"
fi

# If dscl is not account hidden, make it so
dsclIsHidden="$(dscl localhost read "$dsclDir" \
IsHidden | awk '{print $2}' 2>&1)"
if [[ "${dsclIsHidden}" != 1 ]]; then
   dsclMakeHidden="$(dscl localhost create "$dsclDir" \
   IsHidden "$dsclIsHidden" 1 2>&1)"
   if [[ "$?" -gt 0 ]]; then
      write_log "Error: ${dsclMakeHidden}"
   else
      write_log "Info: dscl User is correct: hidden"
   fi
else
   write_log "Info: dscl User is correct: hidden"
fi

# Setting permissions just in case

# Removing any preexisting ACLs
write_log "Info: Removing ACLs..."
aclFix="$(chmod -RN "$rightDir" 2>&1)"
check=$?
checkTest "$check" "$aclFix"

# Remove any file immutable flag which causes opperation not supported
write_log "Info: Removing user immutable flag..."
iFlagFix="$(chflags -R nouchg "$rightDir" 2>&1)"
check=$?
checkTest "$check" "$iFlagFix"

# Make the user the owner
write_log "Info: Making $managementUser the owner of their Home Directory..."
ownerFix="$(chown -R "$managementUser:staff" "$rightDir" 2>&1)"
check=$?
checkTest "$check" "$ownerFix"

# Set permission to all for owner and none for everyone else, recursively
write_log "Info: Setting permission to 700 recursively..."
ownerPermFix="$(chmod -R 700 "$rightDir" 2>&1)"
check=$?
checkTest "$check" "$ownerPermFix"

# Set folder to hidden
write_log "Info: Setting folder flag hidden..."
hideDir="$(chflags hidden "$rightDir" 2>&1)"
check=$?
checkTest "$check" "$hideDir"

write_log "End"
#Exit
exit 0
