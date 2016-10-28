pkg_name=dotnet-core
pkg_origin=core
pkg_version=1.0.4
pkg_license=('MIT')
pkg_description=".NET Core is a blazing fast, lightweight and modular platform
  for creating web applications and services that run on Windows,
  Linux and Mac."
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_source=https://github.com/dotnet/coreclr/archive/v${pkg_version}.tar.gz
pkg_shasum=b49ba545fe632dfd5426669ca3300009a5ffd1ccf3c1cf82303dcf44044db33d
pkg_deps=()
pkg_build_deps=(
  core/which
  core/python2
  core/llvm
  core/make
  core/cmake
  core/gcc-libs
  core/gcc
  core/curl
  core/coreutils
  core/patchelf
  core/glibc
  core/icu/57.1
  core/libunwind
  core/lttng-ust
  core/util-linux
)
pkg_bin_dirs=(bin)
pkg_include_dirs=(include)
pkg_lib_dirs=(lib)

do_prepare() {
  do_default_prepare

  cp $(pkg_path_for gcc)/lib/gcc/x86_64-unknown-linux-gnu/5.2.0/crtbegin*  $(pkg_path_for llvm)/lib/clang/3.6.2
  cp $(pkg_path_for gcc)/lib/gcc/x86_64-unknown-linux-gnu/5.2.0/crtend*  $(pkg_path_for llvm)/lib/clang/3.6.2
  cp $(pkg_path_for glibc)/lib/crt*  $(pkg_path_for llvm)/lib/clang/3.6.2

  pushd $HAB_CACHE_SRC_PATH/coreclr-${pkg_version}/
  old_icu='/usr/local/opt/icu4c'
  file_to_change='src/corefx/System.Globalization.Native/CMakeLists.txt'
  [[ -f $file_to_change ]] && sed -e "s%$old_icu%$(pkg_path_for icu)%g" -i $file_to_change

  find_lib='find_library(ICUUC icuuc'
  [[ -f $file_to_change ]] && sed -e "s%$find_lib%$find_lib HINTS $(pkg_path_for icu)/lib%g" -i $file_to_change
  find_lib='find_library(ICUI18N icui18n'
  [[ -f $file_to_change ]] && sed -e "s%$find_lib%$find_lib HINTS $(pkg_path_for icu)/lib%g" -i $file_to_change
  find_lib='find_library(ICUCORE icucore'
  [[ -f $file_to_change ]] && sed -e "s%$find_lib%$find_lib HINTS $(pkg_path_for icu)/lib%g" -i $file_to_change
 
  file_to_change='src/ToolBox/SOS/lldbplugin/CMakeLists.txt'
  [[ -f $file_to_change ]] && sed -e "s/NOT ENABLE_LLDBPLUGIN/ENABLE_LLDBPLUGIN/g" -i $file_to_change
  
  find_include='include_directories(SYSTEM /usr/local/include)'
  lttng_include="set(FEATURE_EVENT_TRACE 0)"
  file_to_change='src/pal/src/CMakeLists.txt'
  [[ -f $file_to_change ]] && sed -e "s%$find_include%$find_include\n$lttng_include%g" -i $file_to_change

  find_lib='find_library(UNWIND NAMES unwind'
  [[ -f $file_to_change ]] && sed -e "s%$find_lib%$find_lib HINTS $(pkg_path_for libunwind)/lib%g" -i $file_to_change

  popd

  export CFLAGS="$CFLAGS -I$(pkg_path_for gcc)/include/c++/5.2.0 -I$(pkg_path_for gcc)/include/c++/5.2.0/x86_64-unknown-linux-gnu"
  export LDFLAGS="$LDFLAGS -L$(pkg_path_for gcc)/lib/gcc/x86_64-unknown-linux-gnu/5.2.0 -L$(pkg_path_for gcc)/lib64/gcc/x86_64-unknown-linux-gnu/5.2.0"
}

do_build() {

  mkdir -p $HAB_CACHE_SRC_PATH/$pkg_dirname/bin
  mkdir -p $HAB_CACHE_SRC_PATH/$pkg_dirname/bin/Product/Linux.x64.Release
  mkdir -p $HAB_CACHE_SRC_PATH/$pkg_dirname/bin/Logs
  mkdir -p $HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release
  mkdir -p $HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider_new
  mkdir -p $HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider

  echo "Laying out dynamically generated files consumed by the build system "
  echo "Laying out dynamically generated Event Logging Test files"
  $(pkg_path_for python2)/bin/python -B -Wall -Werror "$HAB_CACHE_SRC_PATH/$pkg_dirname/src/scripts/genXplatEventing.py" --man "$HAB_CACHE_SRC_PATH/$pkg_dirname/src/vm/ClrEtwAll.man" --exc "$HAB_CACHE_SRC_PATH/$pkg_dirname/src/vm/ClrEtwAllMeta.lst" --testdir "$HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider_new/tests"

  echo "Laying out dynamically generated Event Logging Implementation of Lttng"
  $(pkg_path_for python2)/bin/python -B -Wall -Werror "$HAB_CACHE_SRC_PATH/$pkg_dirname/src/scripts/genXplatLttng.py" --man "$HAB_CACHE_SRC_PATH/$pkg_dirname/src/vm/ClrEtwAll.man" --intermediate "$HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider_new"

  echo "Cleaning the temp folder of dynamically generated Event Logging files"
  $(pkg_path_for python2)/bin/python -B -Wall -Werror -c "import sys;sys.path.insert(0,\"$HAB_CACHE_SRC_PATH/$pkg_dirname/src/scripts\"); from Utilities import *;UpdateDirectory(\"$HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider\",\"$HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider_new\")"

  rm -rf "$HAB_CACHE_SRC_PATH/$pkg_dirname/bin/obj/Linux.x64.Release/Generated/eventprovider_new"

  echo "static char sccsid[] __attribute__((used)) = \"@(#)No version information produced\";" > "$HAB_CACHE_SRC_PATH/$pkg_dirname/version.cpp"
  
  export CC="$(pkg_path_for llvm)/bin/clang"
  export CXX="$(pkg_path_for llvm)/bin/clang++"  
  export LD_RUN_PATH=$LD_RUN_PATH:$(pkg_path_for gcc)/lib:$(pkg_path_for icu)/lib
  
  cmake \
    -v -G "Unix Makefiles" \
    "-DCMAKE_INSTALL_PREFIX:PATH=$pkg_prefix" \
    "-DCMAKE_CXX_FLAGS:PATH=$CFLAGS -isystem $(pkg_path_for glibc)/include -isystem $(pkg_path_for libunwind)/include -Wall -Wno-null-conversion -std=c++11" \
    "-DCMAKE_C_FLAGS:PATH=$CFLAGS -isystem $(pkg_path_for glibc)/include -Wall -std=c11" \
    "-DCMAKE_SHARED_LINKER_FLAGS:PATH=$LDFLAGS" \
    "-DCMAKE_INSTALL_RPATH:STRING=$(pkg_path_for gcc)/lib" \
    "-DCMAKE_USER_MAKE_RULES_OVERRIDE=$HAB_CACHE_SRC_PATH/$pkg_dirname/src/pal/tools/clang-compiler-override.txt" \
    "-DCMAKE_AR=$(pkg_path_for llvm)/bin/llvm-ar" \
    "-DCMAKE_LINKER=$(pkg_path_for llvm)/bin/llvm-link" \
    "-DCMAKE_NM=$(pkg_path_for llvm)/bin/llvm-nm" \
    "-DCMAKE_OBJDUMP=$(pkg_path_for llvm)/bin/llvm-objdump" \
    "-DCMAKE_BUILD_TYPE=RELEASE" \
    "-DCMAKE_ENABLE_CODE_COVERAGE=OFF" \
    "-DCMAKE_EXPORT_COMPILE_COMMANDS=1 " \
    "-DCLR_CMAKE_BUILD_TESTS=OFF" \
    $HAB_CACHE_SRC_PATH/$pkg_dirname
}
