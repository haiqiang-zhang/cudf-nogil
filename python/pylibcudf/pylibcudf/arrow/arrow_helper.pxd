from libcpp.vector cimport vector
from libcpp.memory cimport shared_ptr
from libcpp.string cimport string
from libc.stdint cimport int64_t
from pyarrow.lib cimport ArrowArray, ArrowSchema

cdef extern from "arrow/api.h" namespace "arrow" nogil:
    cdef cppclass Status:
        pass

    cdef cppclass Array:
        pass

    cdef cppclass Int64Array(Array):
        pass

    cdef cppclass Int64Builder:
        Int64Builder()
        Status AppendValues(const int64_t *values, int64_t length)
        Status Finish(shared_ptr[Array]* out)


cdef extern from "arrow/c/bridge.h" namespace "arrow" nogil:
    cdef cppclass Status:
        bint ok() const
        const char* message() const

    Status ExportArray(
        const Array& array,
        ArrowArray* out,
        ArrowSchema* out_schema
    )