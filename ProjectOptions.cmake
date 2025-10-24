include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(GlueCppLinter_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(GlueCppLinter_setup_options)
  option(GlueCppLinter_ENABLE_HARDENING "Enable hardening" ON)
  option(GlueCppLinter_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    GlueCppLinter_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    GlueCppLinter_ENABLE_HARDENING
    OFF)

  GlueCppLinter_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR GlueCppLinter_PACKAGING_MAINTAINER_MODE)
    option(GlueCppLinter_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(GlueCppLinter_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(GlueCppLinter_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(GlueCppLinter_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(GlueCppLinter_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(GlueCppLinter_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(GlueCppLinter_ENABLE_PCH "Enable precompiled headers" OFF)
    option(GlueCppLinter_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(GlueCppLinter_ENABLE_IPO "Enable IPO/LTO" ON)
    option(GlueCppLinter_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(GlueCppLinter_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(GlueCppLinter_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(GlueCppLinter_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(GlueCppLinter_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(GlueCppLinter_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(GlueCppLinter_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(GlueCppLinter_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(GlueCppLinter_ENABLE_PCH "Enable precompiled headers" OFF)
    option(GlueCppLinter_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      GlueCppLinter_ENABLE_IPO
      GlueCppLinter_WARNINGS_AS_ERRORS
      GlueCppLinter_ENABLE_USER_LINKER
      GlueCppLinter_ENABLE_SANITIZER_ADDRESS
      GlueCppLinter_ENABLE_SANITIZER_LEAK
      GlueCppLinter_ENABLE_SANITIZER_UNDEFINED
      GlueCppLinter_ENABLE_SANITIZER_THREAD
      GlueCppLinter_ENABLE_SANITIZER_MEMORY
      GlueCppLinter_ENABLE_UNITY_BUILD
      GlueCppLinter_ENABLE_CLANG_TIDY
      GlueCppLinter_ENABLE_CPPCHECK
      GlueCppLinter_ENABLE_COVERAGE
      GlueCppLinter_ENABLE_PCH
      GlueCppLinter_ENABLE_CACHE)
  endif()

  GlueCppLinter_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (GlueCppLinter_ENABLE_SANITIZER_ADDRESS OR GlueCppLinter_ENABLE_SANITIZER_THREAD OR GlueCppLinter_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(GlueCppLinter_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(GlueCppLinter_global_options)
  if(GlueCppLinter_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    GlueCppLinter_enable_ipo()
  endif()

  GlueCppLinter_supports_sanitizers()

  if(GlueCppLinter_ENABLE_HARDENING AND GlueCppLinter_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR GlueCppLinter_ENABLE_SANITIZER_UNDEFINED
       OR GlueCppLinter_ENABLE_SANITIZER_ADDRESS
       OR GlueCppLinter_ENABLE_SANITIZER_THREAD
       OR GlueCppLinter_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${GlueCppLinter_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${GlueCppLinter_ENABLE_SANITIZER_UNDEFINED}")
    GlueCppLinter_enable_hardening(GlueCppLinter_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(GlueCppLinter_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(GlueCppLinter_warnings INTERFACE)
  add_library(GlueCppLinter_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  GlueCppLinter_set_project_warnings(
    GlueCppLinter_warnings
    ${GlueCppLinter_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(GlueCppLinter_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    GlueCppLinter_configure_linker(GlueCppLinter_options)
  endif()

  include(cmake/Sanitizers.cmake)
  GlueCppLinter_enable_sanitizers(
    GlueCppLinter_options
    ${GlueCppLinter_ENABLE_SANITIZER_ADDRESS}
    ${GlueCppLinter_ENABLE_SANITIZER_LEAK}
    ${GlueCppLinter_ENABLE_SANITIZER_UNDEFINED}
    ${GlueCppLinter_ENABLE_SANITIZER_THREAD}
    ${GlueCppLinter_ENABLE_SANITIZER_MEMORY})

  set_target_properties(GlueCppLinter_options PROPERTIES UNITY_BUILD ${GlueCppLinter_ENABLE_UNITY_BUILD})

  if(GlueCppLinter_ENABLE_PCH)
    target_precompile_headers(
      GlueCppLinter_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(GlueCppLinter_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    GlueCppLinter_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(GlueCppLinter_ENABLE_CLANG_TIDY)
    GlueCppLinter_enable_clang_tidy(GlueCppLinter_options ${GlueCppLinter_WARNINGS_AS_ERRORS})
  endif()

  if(GlueCppLinter_ENABLE_CPPCHECK)
    GlueCppLinter_enable_cppcheck(${GlueCppLinter_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(GlueCppLinter_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    GlueCppLinter_enable_coverage(GlueCppLinter_options)
  endif()

  if(GlueCppLinter_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(GlueCppLinter_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(GlueCppLinter_ENABLE_HARDENING AND NOT GlueCppLinter_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR GlueCppLinter_ENABLE_SANITIZER_UNDEFINED
       OR GlueCppLinter_ENABLE_SANITIZER_ADDRESS
       OR GlueCppLinter_ENABLE_SANITIZER_THREAD
       OR GlueCppLinter_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    GlueCppLinter_enable_hardening(GlueCppLinter_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
