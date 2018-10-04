#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 10_setup_oudsm_12c.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to install Oracle Unified Directory Services Manager 12c.
# Notes......: Script would like to be executed as oracle :-).
# Reference..: --
# License....: Licensed under the Universal Permissive License v 1.0 as 
#              shown at http://oss.oracle.com/licenses/upl.
# ---------------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ---------------------------------------------------------------------------

# - Environment Variables ---------------------------------------------------
# source genric environment variables and functions
source "$(dirname ${BASH_SOURCE[0]})/00_setup_oradba_init.sh"

# define the software packages
export OUD_BASE_PKG=${OUD_BASE_PKG:-"p26270957_122130_Generic.zip"}
export FMW_BASE_PKG=${FMW_BASE_PKG:-"p26269885_122130_Generic.zip"}
export OUD_PATCH_PKG=${OUD_PATCH_PKG:-"p28245820_122130_Generic.zip"}
export FMW_PATCH_PKG=${FMW_PATCH_PKG:-"p27912627_122130_Generic.zip"}
export OUD_OPATCH_PKG=${OUD_OPATCH_PKG:-"p28186730_139400_Generic.zip"}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder

# define Oracle specific variables
export ORACLE_ROOT=${ORACLE_ROOT:-"/u00"}       # root folder for ORACLE_BASE and binaries
export ORACLE_DATA=${ORACLE_DATA:-"/u01"}       # Oracle data folder eg volume for docker
export ORACLE_BASE=${ORACLE_BASE:-"${ORACLE_ROOT}/app/oracle"}
export ORACLE_INVENTORY=${ORACLE_INVENTORY:-"${ORACLE_ROOT}/app/oraInventory"}
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"fmw12.2.1.3.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"

# define generic variables for software, download etc
export JAVA_HOME=${JAVA_HOME:-$(dirname $(dirname $(find ${ORACLE_BASE} /usr/java -name javac 2>/dev/null|sort -r|head -1) 2>/dev/null) 2>/dev/null)}
export OPT_DIR=${OPT_DIR:-"/opt"}
export SOFTWARE=${SOFTWARE:-"${OPT_DIR}/stage"} # local software stage folder
export SOFTWARE_REPO=${SOFTWARE_REPO:-""}       # URL to software for curl fallback
export DOWNLOAD=${DOWNLOAD:-"/tmp/download"}    # temporary download location
export CLEANUP=${CLEANUP:-"true"}               # Flag to set yum clean up
export SLIM=${SLIM:-"false"}                    # flag to enable SLIM setup
# - EOF Environment Variables -----------------------------------------------

# - Initialization ----------------------------------------------------------
# Make sure root does not run our script
if [ ! $EUID -ne 0 ]; then
   echo "This script must not be run as root" 1>&2
   exit 1
fi

# Replace place holders in responce file
echo " - Prepare response files ---------------------------------------------"
cp ${ORADBA_RSP}/oud_install.rsp.tmpl /tmp/oud_install.rsp
mkdir -p ${DOWNLOAD}

echo "inventory_loc=${ORACLE_INVENTORY}"   >/tmp/oraInst.loc
echo "inst_group=oinstall"                 >>/tmp/oraInst.loc
# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install FMW binaries ----------------------------------------------------
echo " - Install Oracle FMW binaries ----------------------------------------"
if [ -n "${FMW_BASE_PKG}" ]; then
    if get_software "${FMW_BASE_PKG}"; then          # Check and get binaries
        cd ${DOWNLOAD}
        # unpack OUD binary package
        FMW_BASE_LOG=$(basename ${FMW_BASE_PKG} .zip).log
        $JAVA_HOME/bin/jar xvf ${SOFTWARE}/${FMW_BASE_PKG} >${FMW_BASE_LOG}

        # get the jar file name from the logfile
        FMW_BASE_JAR=$(grep -i jar ${FMW_BASE_LOG} |cut -d' ' -f3| tr -d " ")

        # Install OUD binaries
        $JAVA_HOME/bin/java -jar ${DOWNLOAD}/$FMW_BASE_JAR -silent \
        -responseFile /tmp/oud_install.rsp \
        -invPtrLoc /tmp/oraInst.loc \
        -ignoreSysPrereqs -force \
        -novalidation ORACLE_HOME=${ORACLE_HOME} \
        INSTALL_TYPE="WebLogic Server"

        # remove files on docker builds
        rm -rf ${DOWNLOAD}/$FMW_BASE_JAR
        running_in_docker && rm -rf ${SOFTWARE}/${FMW_BASE_PKG}
    else
        echo "ERROR:   No base software package specified. Abort installation."
        exit 1
    fi
fi

# - Install oud binaries ----------------------------------------------------
echo " - Install Oracle OUD binaries ----------------------------------------"
if [ -n "${OUD_BASE_PKG}" ]; then
    if get_software "${OUD_BASE_PKG}"; then          # Check and get binaries
        cd ${DOWNLOAD}
        # unpack OUD binary package
        OUD_BASE_LOG=$(basename ${OUD_BASE_PKG} .zip).log
        $JAVA_HOME/bin/jar xvf ${SOFTWARE}/${OUD_BASE_PKG} >${OUD_BASE_LOG}

        # get the jar file name from the logfile
        OUD_BASE_JAR=$(grep -i jar ${OUD_BASE_LOG} |cut -d' ' -f3| tr -d " ")

        # Install OUD binaries
        $JAVA_HOME/bin/java -jar ${DOWNLOAD}/$OUD_BASE_JAR -silent \
        -responseFile /tmp/oud_install.rsp \
        -invPtrLoc /tmp/oraInst.loc \
        -ignoreSysPrereqs -force \
        -novalidation ORACLE_HOME=${ORACLE_HOME} \
         INSTALL_TYPE="Collocated Oracle Unified Directory Server (Managed through WebLogic server)"

        # remove files on docker builds
        rm -rf ${DOWNLOAD}/$OUD_BASE_JAR
        running_in_docker && rm -rf ${SOFTWARE}/${OUD_BASE_PKG}
    else
        echo "ERROR:   No base software package specified. Abort installation."
        exit 1
    fi
fi

# install patch any of the patch variable is if defined
if [ ! -z "${OUD_PATCH_PKG}" ] || [ ! -z "${OUD_OPATCH_PKG}" ] || [ ! -z "${FMW_PATCH_PKG}" ]; then 
    ${ORADBA_BIN}/11_setup_oud_patch.sh
else
    echo "INFO:    Skip patch installation. No patch packages specified."
fi

echo " - CleanUp OUDSM installation -----------------------------------------"
# Remove not needed components
rm -rf ${ORACLE_HOME}/inventory/backup/*            # OUI backup

# Temp locations§
rm -rf ${DOWNLOAD}/*
rm -rf /tmp/*.rsp
rm -rf /tmp/*.loc
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle
rm -rf /tmp/OraInstall*

# remove all the logs....
find ${ORACLE_BASE}/cfgtoollogs . -type f -name *.log -exec rm {} \;
find ${ORACLE_BASE}/local . -type f -name *.log -exec rm {} \;
find ${ORACLE_INVENTORY} . -type f -name *.log -exec rm {} \;
find ${ORACLE_BASE}/product . -type f -name *.log -exec rm {} \;

if [ "${SLIM^^}" == "TRUE" ]; then
    rm -rf ${ORACLE_HOME}/inventory                 # remove inventory
    rm -rf ${ORACLE_HOME}/oui                       # remove oui
    rm -rf ${ORACLE_HOME}/OPatch                    # remove OPatch
    rm -rf ${DOWNLOAD}/*
    rm -rf /tmp/OraInstall*
    rm -rf ${ORACLE_HOME}/.patch_storage            # remove patch storage
fi
# --- EOF --------------------------------------------------------------------