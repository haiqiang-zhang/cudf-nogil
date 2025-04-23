set(cython_sources
    arrow_helper.pyx
)
set(linked_libraries cudf::cudf)
rapids_cython_create_modules(
  CXX
  SOURCE_FILES "${cython_sources}"
  LINKED_LIBRARIES "${linked_libraries}" MODULE_PREFIX pylibcudf_ ASSOCIATED_TARGETS cudf
)


find_package(Python3 COMPONENTS Interpreter REQUIRED)
execute_process(
  COMMAND ${Python3_EXECUTABLE} -c
    "import pyarrow as pa; print(pa.get_include())"
  OUTPUT_VARIABLE PYARROW_CPP_INCLUDE
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

execute_process(
  COMMAND ${Python3_EXECUTABLE}
          -c "import numpy; print(numpy.get_include())"
  OUTPUT_VARIABLE NUMPY_INCLUDE_DIR
  OUTPUT_STRIP_TRAILING_WHITESPACE
)

target_include_directories(pylibcudf_arrow_helper PUBLIC ${PYARROW_CPP_INCLUDE} ${NUMPY_INCLUDE_DIR})

find_package(Arrow REQUIRED)



target_link_libraries(pylibcudf_arrow_helper PUBLIC Arrow::arrow_shared)
  