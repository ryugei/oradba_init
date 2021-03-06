#!/bin/bash
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: 11_setup_db_patch.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2018.09.27
# Revision...: 
# Purpose....: Script to patch Oracle Database binaries
# Notes......: - Script would like to be executed as oracle :-)
#              - If the required software is not in /opt/stage, an attempt is
#                made to download the software package with curl from 
#                ${SOFTWARE_REPO} In this case, the environment variable must 
#                point to a corresponding URL.
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
export DB_PATCH_PKG=${DB_PATCH_PKG:-""}
export DB_OJVM_PKG=${DB_OJVM_PKG:-""}
export DB_OPATCH_PKG=${DB_OPATCH_PKG:-"p6880880_180000_Linux-x86-64.zip"}

# define oradba specific variables
export ORADBA_BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)"
export ORADBA_BASE="$(dirname ${ORADBA_BIN})"
export ORADBA_RSP="${ORADBA_BASE}/rsp"          # oradba init response file folder

# define Oracle specific variables
export ORACLE_HOME_NAME=${ORACLE_HOME_NAME:-"18.3.0.0"}
export ORACLE_HOME="${ORACLE_HOME:-${ORACLE_BASE}/product/${ORACLE_HOME_NAME}}"

# define generic variables for software, download etc
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

# prepare 11.2 OPatch response file
if [ ${ORACLE_MAJOR_RELEASE} -eq 112 ]; then
    cp ${ORADBA_RSP}/ocm.rsp.tmpl /tmp/ocm.rsp
    OPATCH_RSP="-ocmrf /tmp/ocm.rsp"
fi

# add oracle perl to the PATH for env without perl e.g. docker
if [ ! -n "$(command -v perl)" ]; then
    export PATH=$PATH:$ORACLE_HOME/perl/bin
fi

# - EOF Initialization ------------------------------------------------------

# - Main --------------------------------------------------------------------
# - Install OPatch ----------------------------------------------------------
echo " - Install OPatch -----------------------------------------------------"
if [ -n "${DB_OPATCH_PKG}" ]; then
    if get_software "${DB_OPATCH_PKG}"; then           # Check and get binaries
        rm -rf ${ORACLE_HOME}/OPatch                # remove old OPatch
        echo " - unzip ${SOFTWARE}/${DB_OPATCH_PKG} to ${ORACLE_HOME}"
        unzip -q -o ${SOFTWARE}/${DB_OPATCH_PKG} \
            -d ${ORACLE_HOME}/                      # unpack OPatch binary package
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_OPATCH_PKG}
    else
        echo "WARNING: Could not find local or remote OPatch package. Skip OPatch update."
    fi
else
    echo "INFO:    No OPatch package specified. Skip OPatch update."
fi

# - Install database patch (RU/PSU) -----------------------------------------
echo " - Install database patch (RU/PSU) ------------------------------------"
if [ -n "${DB_PATCH_PKG}" ]; then
    if get_software "${DB_PATCH_PKG}"; then         # Check and get binaries
        DB_PATCH_ID=$(echo ${DB_PATCH_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        echo " - unzip ${SOFTWARE}/${DB_PATCH_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${DB_PATCH_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${DB_PATCH_ID}

        ${ORACLE_HOME}/OPatch/opatch apply -silent $OPATCH_RSP
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_PATCH_PKG}
        rm -rf ${DOWNLOAD}/${DB_PATCH_ID}           # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo "WARNING: Could not find local or remote database patch (RU/PSU) package. Skip database patch (RU/PSU) installation."
    fi
else
    echo "INFO:    No database patch (RU/PSU) package specified. Skip database patch (RU/PSU) installation."
fi

# - Install OJVM RU ---------------------------------------------------------
echo " - Install OJVM RU ----------------------------------------------------"
if [ -n "${DB_OJVM_PKG}" ]; then
    if get_software "${DB_OJVM_PKG}"; then          # Check and get binaries
        DB_OJVM_ID=$(echo ${DB_OJVM_PKG}| sed -E 's/p([[:digit:]]+).*/\1/')
        echo " - unzip ${SOFTWARE}/${DB_OJVM_PKG} to ${DOWNLOAD}"
        unzip -q -o ${SOFTWARE}/${DB_OJVM_PKG} \
            -d ${DOWNLOAD}/                         # unpack OPatch binary package
        cd ${DOWNLOAD}/${DB_OJVM_ID}
        ${ORACLE_HOME}/OPatch/opatch apply -silent $OPATCH_RSP
        # remove files on docker builds
        running_in_docker && rm -rf ${SOFTWARE}/${DB_OJVM_PKG}
        rm -rf ${DOWNLOAD}/${DB_OJVM_ID}            # remove the binary packages
        rm -rf ${DOWNLOAD}/PatchSearch.xml          # remove the binary packages
    else
        echo "WARNING: Could not find local or remote OJVM package. Skip OJVM installation."
    fi
else
    echo "INFO:    No OJVM package specified. Skip OJVM installation."
fi

echo " - CleanUp DB patch installation --------------------------------------"
# Temp locations
rm -rf ${DOWNLOAD}/*
rm -rf /tmp/*.rsp
rm -rf /tmp/InstallActions*
rm -rf /tmp/CVU*oracle
rm -rf /tmp/OraInstall*

running_in_docker && rm -rf ${ORACLE_HOME}/.patch_storage       # remove patch storage
running_in_docker && rm -rf ${ORACLE_HOME}/inventory/backup/*   # OUI backup

# remove all the logs....
find ${ORACLE_INVENTORY} -type f -name *.log -exec rm {} \;
find ${ORACLE_BASE}/product -type f -name *.log -exec rm {} \;
# --- EOF --------------------------------------------------------------------