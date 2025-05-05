from libcpp.vector cimport vector
from libcpp.memory cimport shared_ptr
from libcpp.string cimport string
from libc.stdint cimport int64_t, uint8_t
from pyarrow.lib cimport ArrowArray, ArrowSchema, ArrowArrayStream

cdef extern from "arrow/api.h" namespace "arrow" nogil:
    cdef cppclass Status:
        pass

    cdef cppclass Array:
        pass

    cdef cppclass DataType: 
        pass

    cdef cppclass Int64Array(Array):
        pass


    cdef cppclass Int64Builder:
        Int64Builder() except+
        Status AppendValues(const int64_t *values, int64_t length) except+
        void Append(long long) except+
        void AppendNull() except+
        Status Finish(shared_ptr[Array]* out) except+

    cdef cppclass StringBuilder:
        StringBuilder() except+
        Status AppendValues(const vector[string]&, const uint8_t *valid_bytes = NULL) except+
        void AppendNull() except+
        void Finish(shared_ptr[Array]*) except+


    cdef cppclass Field: 
        pass
    shared_ptr[Field] field(const string&, shared_ptr[DataType])

    cdef cppclass Schema: 
        pass
    shared_ptr[Schema] schema(vector[shared_ptr[Field]])



cdef extern from "arrow/c/bridge.h" namespace "arrow" nogil:
    cdef cppclass Status:
        bint ok() const
        const char* message() const

    Status ExportArray(
        const Array& array,
        ArrowArray* out,
        ArrowSchema* out_schema
    )
