#!/bin/bash

set -euxo pipefail

pushd tests

# It seems that during rattler-build's activation the header includes are erroneously point NOT to PREFIX.
export CFLAGS="${CFLAGS//${CONDA_PREFIX}/${PREFIX}}"
export CPPFLAGS="${CPPFLAGS//${CONDA_PREFIX}/${PREFIX}}"
export CXXFLAGS="${CXXFLAGS//${CONDA_PREFIX}/${PREFIX}}"

source gen-bazel-toolchain

mkdir -p third_party/systemlibs
cp -ap "${PREFIX}/share/bazel/systemlibs/protobuf" third_party/systemlibs/
cp -ap "${PREFIX}/share/bazel/protobuf/bazel" third_party/systemlibs/protobuf/
export ABSEIL_VERSION="$(grep -l '"name": "libabseil"' "${PREFIX}/conda-meta/"*.json | head -1 | xargs grep '"version"' | sed -E 's/.*"version":\s*"([^"]+)".*/\1/')"
export PROTOC_VERSION="$(grep -l '"name": "libprotobuf"' "${PREFIX}/conda-meta/"*.json | head -1 | xargs grep '"version"' | sed -E 's/.*"version":\s*"([^"]+)".*/\1/' | sed -E 's/^[0-9]+\.([0-9]+\.[0-9]+)$/\1/')"
sed -i "s:PROTOC_VERSION:${PROTOC_VERSION}:" MODULE.bazel
sed -i "s:ABSEIL_VERSION:${ABSEIL_VERSION}:" third_party/systemlibs/protobuf/MODULE.bazel

bazel build \
  --subcommands \
  --logging=6 \
  --verbose_failures \
  --define=PROTOC_PREFIX=${PREFIX} \
  --define=PROTOBUF_INCLUDE_PATH=${PREFIX}/include \
  --platforms=//bazel_toolchain:target_platform \
  --host_platform=//bazel_toolchain:build_platform \
  --extra_toolchains=//bazel_toolchain:cc_cf_toolchain \
  --extra_toolchains=//bazel_toolchain:cc_cf_host_toolchain \
  --@com_google_protobuf//bazel/flags:allow_nonstandard_protoc \
  --extra_toolchains=@com_google_protobuf//bazel/private/oss/toolchains:cc_source_toolchain \
  --extra_toolchains=@com_google_protobuf//bazel/private/oss/toolchains:protoc_sources_toolchain \
  //:smoke_test
./bazel-bin/smoke_test
bazel clean --expunge
