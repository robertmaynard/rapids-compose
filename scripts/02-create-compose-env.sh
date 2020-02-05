#!/usr/bin/env bash

set -Eeo pipefail

cd $(dirname "$(realpath "$0")")/../../

select_version() {
    MSG="$1"
    DEFAULT="$2"
    SELECTION=""
    read -p "$MSG (default: $DEFAULT) " SELECTION </dev/tty
    if [ "$SELECTION" = "" ]; then
        SELECTION="$DEFAULT";
    fi
    echo "$SELECTION"
}

choose_bool_option() {
    MSG="$1"
    DEFAULT="$2"
    SELECTION=""
    while true; do
        read -p "$MSG (default: $DEFAULT) " SELECTION </dev/tty
        if [ "$SELECTION" = "" ]; then
            SELECTION="$DEFAULT";
        fi
        case $SELECTION in
            [Nn]* ) echo "NO"; break;;
            [Yy]* ) echo "YES"; break;;
            * ) >&2 echo "Please answer 'y' or 'n'";;
        esac
    done
}

echo "###
Configure RAPIDS environment \`.env\` file
###
";

vGCC=$(select_version "Please enter your desired GCC version (5/7)" "5")
CUDA_VERSION=$(select_version "Please enter your desired CUDA version (9.2/10.0/10.1)" "10.0")
PYTHON_VERSION=$(select_version "Please enter your desired Python version (3.6/3.7)" "3.7")
CMAKE_BUILD_TYPE=$(select_version "Select RAPIDS CMake project built type (Debug/Release)" "Release")
NVIDIA_VISIBLE_DEVICES=$(select_version "Select which GPU the container should use (0,..num_gpus)" "0")
BUILD_TESTS=$(select_version "Select whether to configure to build RAPIDS tests (ON/OFF)" "ON")
BUILD_BENCHMARKS=$(select_version "Select whether to configure to build RAPIDS benchmarks (ON/OFF)" "ON")

USE_CCACHE=$(choose_bool_option "Use ccache for C++ builds? (Y/N)" "YES")

BUILD_RMM="YES"
BUILD_CUDF="YES"
BUILD_CUGRAPH=$(choose_bool_option "Build cuGraph C++ and Cython? (Y/N)" "YES")

if [ "$BUILD_CUGRAPH" = "NO" ]; then
    BUILD_CUDF=$(choose_bool_option "Build cuDF C++ and Cython? (Y/N)" "YES")
fi

if [ "$BUILD_CUDF" = "NO" ]; then
    BUILD_RMM=$(choose_bool_option "Build rmm C++ and Cython? (Y/N)" "YES")
fi

compose_env_file() {
    echo "\
# Build arguments
RAPIDS_HOME=$PWD
GCC_VERSION=$vGCC
CXX_VERSION=$vGCC
CUDA_VERSION=$CUDA_VERSION
PYTHON_VERSION=$PYTHON_VERSION
LINUX_VERSION=$LINUX_VERSION

# Whether to use ccache (https://ccache.dev/) to speed up gcc/nvcc build times
USE_CCACHE=$USE_CCACHE
# Whether to build C++/cuda tests/benchmarks during \`make rapids\` target
BUILD_TESTS=$BUILD_TESTS
BUILD_BENCHMARKS=$BUILD_BENCHMARKS
# Set to \`Debug\` to compile in debug symbols during \`make rapids\` target
CMAKE_BUILD_TYPE=$CMAKE_BUILD_TYPE

###
# Select which RAPIDS projects to build
###
# Whether to build rmm C++ and Cython
BUILD_RMM=$BUILD_RMM
# Whether to build cuDF C++ and Cython (implies BUILD_RMM=YES)
BUILD_CUDF=$BUILD_CUDF
# Whether to build cuGraph C++ and Cython (implies BUILD_CUDF=YES)
BUILD_CUGRAPH=$BUILD_CUGRAPH

# Select which GPU(s) the container will use when running tests/notebooks
NVIDIA_VISIBLE_DEVICES=$NVIDIA_VISIBLE_DEVICES
"
}

if [ ! -f "$PWD/compose/.env" ]; then
    compose_env_file > "$PWD/compose/.env"
fi

touch "$PWD/compose/.env"

CHANGED="$(diff -qwB "$PWD/compose/.env" <(compose_env_file) || true)"

if [ -n "${CHANGED// }" ]; then
    echo "Difference between current .env and proposed .env:";
    diff -wBy --suppress-common-lines "$PWD/compose/.env" <(compose_env_file) || true;
    while true; do
        read -p "Do you wish to overwrite your current compose/.env file? (y/n) " yn </dev/tty
        case $yn in
            [Nn]* ) break;;
            [Yy]* ) compose_env_file > "$PWD/compose/.env"; break;;
            * ) echo "Please answer 'y' or 'n'";;
        esac
    done
fi
