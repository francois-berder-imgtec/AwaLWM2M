#/************************************************************************************************************************
# Copyright (c) 2016, Imagination Technologies Limited and/or its affiliated group companies.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the
# following conditions are met:
#     1. Redistributions of source code must retain the above copyright notice, this list of conditions and the
#        following disclaimer.
#     2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the
#        following disclaimer in the documentation and/or other materials provided with the distribution.
#     3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
#        products derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE 
# USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#************************************************************************************************************************/

#!/bin/bash

set -o errexit

export PATH=$PATH:/opt/microchip/xc32/v1.34/bin
#export PATH=/opt/rh/devtoolset-2/root/usr/bin:$PATH
export PATH=/repos/creator-git/dists/openwrt/staging_dir/target-mipsel_mips32_uClibc-0.9.33.2/host/bin:/repos/creator-git/dists/openwrt/staging_dir/toolchain-mipsel_mips32_gcc-4.9-linaro_uClibc-0.9.33.2/bin:/repos/creator-git/dists/openwrt/staging_dir/toolchain-mipsel_mips32_gcc-4.9-linaro_uClibc-0.9.33.2/bin:/repos/creator-git/dists/openwrt/staging_dir/host/bin:/repos/creator-git/dists/openwrt/staging_dir/host/bin:$PATH
export STAGING_DIR="/repos/creator-git/dists/openwrt/staging_dir/target-mipsel_mips32_uClibc-0.9.33.2"
export ac_cv_func_malloc_0_nonnull=yes
#export VERSION=$(git describe --abbrev=4 --dirty --always --tags)

# clean out old build stuff.
make clean
(cd lib && git clean -dfx)
rm -rf lib/libcoap/config.h   # still needed?
rm -rf lwm2m*.tgz
rm .build_openwrt -rf
rm .build_x86 -rf
rm -rf tools/tools_tests.xml

# build for OpenWRT
make BUILD_DIR=.build_openwrt CMAKE_OPTIONS=-DCMAKE_TOOLCHAIN_FILE=ci/openwrt-toolchain.cmake

# setup lcov
mkdir .build_x86
(cd .build_x86
 lcov --rc lcov_branch_coverage=1 --zerocounters --directory .
 lcov --rc lcov_branch_coverage=1 --capture --initial --directory . --output-file test_lwm2m || true
)

# build for x86 and run test cases
make BUILD_DIR=.build_x86 CMAKE_OPTIONS="-DENABLE_GCOV=ON"
make BUILD_DIR=.build_x86 CMAKE_OPTIONS="-DENABLE_GCOV=ON" tests

# prepare coverage results
# prepare coverage results
(cd .build_x86
 lcov --rc lcov_branch_coverage=1 --no-checksum --directory . --capture --output-file tmp_test_lwm2m.info
 lcov --rc lcov_branch_coverage=1 --remove tmp_test_lwm2m.info "api/tests/*" --output-file tmp_test_lwm2m.info
 lcov --rc lcov_branch_coverage=1 --remove tmp_test_lwm2m.info "api/src/unsupported*" --output-file tmp_test_lwm2m.info
 lcov --rc lcov_branch_coverage=1 --remove tmp_test_lwm2m.info "core/tests/*" --output-file tmp_test_lwm2m.info
 lcov --rc lcov_branch_coverage=1 --remove tmp_test_lwm2m.info "/usr/*" --output-file tmp_test_lwm2m.info
 lcov --rc lcov_branch_coverage=1 --remove tmp_test_lwm2m.info ".build_x86/*" --output-file tmp_test_lwm2m.info
 mkdir -p lcov-html
 cd lcov-html
 genhtml --rc genhtml_branch_coverage=1 ../tmp_test_lwm2m.info
)

# prepare cobertura coverage results
(cd .build_x86
 python ../ci/lcov_cobertura.py tmp_test_lwm2m.info -b ../
)

# run cppcheck
make cppcheck BUILD_DIR=.build_x86

# check docs build
make docs

