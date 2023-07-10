#!/bin/bash
##
# Installs and compiles marian
#

set -x
set -euo pipefail

echo "###### Compiling marian"

test -v CUDA_DIR

marian_dir=$1
threads=$2
extra_args=( "${@:3}" )

mkdir -p "${marian_dir}"
cd "${marian_dir}"
cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCOMPILE_CPU=OFF -DCOMPILE_CUDA=OFF -DCOMPILE_ROCM=ON -DCMAKE_C_COMPILER=$ROCM_PATH/llvm/bin/clang -DCMAKE_CXX_COMPILER=$ROCM_PATH/llvm/bin/clang++ -DCMAKE_HIP_COMPILER=$ROCM_PATH/llvm/bin/clang++ -DUSE_CUDNN=ON -DCOMPILE_TESTS=ON -DUSE_DOXYGEN=OFF "${extra_args[@]}" -DHIP_INCLUDE_DIR=$ROCM_PATH/hip/include/hip
#cmake .. -DUSE_SENTENCEPIECE=on -DUSE_NCCL=off -DUSE_FBGEMM=off -DCOMPILE_CUDA=off -DHIP_DIR=/opt/rocm/hip/cmake -DCOMPILE_ROCM=on -DCOMPILE_CPU=on -DCMAKE_BUILD_TYPE=Release \
#  "${extra_args[@]}"
make -j "${threads}"

echo "###### Done: Compiling marian"
