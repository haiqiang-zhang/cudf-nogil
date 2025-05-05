from cython.operator import dereference

from cpython.buffer cimport (
    PyObject_GetBuffer,
    PyBuffer_Release,
    Py_buffer,
    PyBUF_CONTIG_RO,
    PyBUF_FORMAT,
    PyObject_CheckBuffer,
)
from cpython.pycapsule cimport PyCapsule_GetPointer

from libcpp.memory cimport unique_ptr, make_unique, shared_ptr, make_shared
from libcpp.utility cimport move
from libc.stdint cimport int64_t
from libc.stdlib cimport malloc, free
from libcpp.cast cimport static_cast


from pylibcudf.libcudf cimport copying as cpp_copying

from pylibcudf.libcudf.copying cimport (
    out_of_bounds_policy,
)
from pylibcudf.libcudf.table.table cimport table
from .table cimport Table as cudf_Table


from pylibcudf.libcudf.interop cimport (
    ArrowArray, 
    ArrowArrayStream,
    ArrowSchema, 
    arrow_column,
    arrow_table
)

from pylibcudf.libcudf.merge cimport merge
from pylibcudf.arrow.arrow_helper cimport (
    Int64Builder,
    Array, 
    ExportArray,
)
from pylibcudf.libcudf.types cimport null_order, order, size_type

from libcpp.vector cimport vector
from libcpp.string  cimport string
from pylibcudf.libcudf.table.table_view cimport table_view


__all__ = [
    "multiget",
    "multiset",
]

cpdef cudf_Table multiget(
    cudf_Table source_table,
    object keys_obj,             
    out_of_bounds_policy bounds_policy
):
    """
    GPU‐accelerated multi‐get by gathering rows whose indices match any key in the Python `keys` list.

    Parameters
    ----------
    source_table : Table
        The input GPU table.
    keys : list[int]
        List of integer keys to select.
    bounds_policy : OutOfBoundsPolicy
        Policy for out‐of‐bounds indices (NULLIFY or DONT_CHECK).

    Returns
    -------
    Table
        New Table containing only matching rows.
    """
    cdef Py_ssize_t size
    cdef Py_buffer view
    cdef int64_t* c_keys

    if PyObject_GetBuffer(keys_obj, &view,
        PyBUF_CONTIG_RO | PyBUF_FORMAT) != 0:
        raise TypeError("keys must support buffer protocol (e.g. numpy int64 array)")
    if view.ndim != 1 or view.len != view.itemsize * view.shape[0]:
        PyBuffer_Release(&view)
        raise ValueError("keys must be a 1-D contiguous array")
    if view.format not in (b"q", b"l"):
        PyBuffer_Release(&view)
        raise TypeError("keys must be 64-bit integers")
    size = view.shape[0]
    c_keys = <int64_t*>view.buf


    cdef Int64Builder builder
    cdef shared_ptr[Array] out_array
    cdef ArrowSchema* c_schema
    cdef ArrowArray* c_array
    cdef unique_ptr[arrow_column] c_column
    cdef unique_ptr[table] c_result
    
    with nogil:

        c_schema = <ArrowSchema*>malloc(sizeof(ArrowSchema))
        c_array = <ArrowArray*>malloc(sizeof(ArrowArray))

        builder.AppendValues(c_keys, size)
        builder.Finish(&out_array)

        ExportArray(
            dereference(out_array),
            c_array,
            c_schema,
        )

        c_column = make_unique[arrow_column](
            move(dereference(c_schema)), move(dereference(c_array))
        )
        c_result = cpp_copying.gather(
            source_table.view(),
            c_column.get().view(),
            bounds_policy
        )

        free(c_schema)
        free(c_array)

    return cudf_Table.from_libcudf(move(c_result))

cpdef cudf_Table multiset(
    cudf_Table source_table,
    object keys_obj,
    object destination_obj,
):

    cdef ArrowArrayStream* dest_stream
    cdef ArrowSchema* keys_schema
    cdef ArrowArray* keys_array

    stream = destination_obj.__arrow_c_stream__() 
    dest_stream = (
        <ArrowArrayStream*>PyCapsule_GetPointer(stream, "arrow_array_stream")
    )

    schema, array = keys_obj.__arrow_c_array__()
    keys_schema = <ArrowSchema*>PyCapsule_GetPointer(schema, "arrow_schema")
    keys_array = <ArrowArray*>PyCapsule_GetPointer(array, "arrow_array")

    cdef unique_ptr[arrow_table] dest_table
    cdef unique_ptr[arrow_column] keys_column


    cdef unique_ptr[table] c_result

    with nogil:

        dest_table = make_unique[arrow_table](move(dereference(dest_stream)))

        keys_column = make_unique[arrow_column](
            move(dereference(keys_schema)), move(dereference(keys_array))
        )
        
        c_result = cpp_copying.scatter(
            dest_table.get().view(),
            keys_column.get().view(),
            source_table.view()
        )

    return cudf_Table.from_libcudf(move(c_result))




    # # ------------------------------------------------------------------
    # # 1. Validation & metadata collection (under GIL) -------------------
    # # ------------------------------------------------------------------

    # if not isinstance(destination_obj, dict):
    #     raise TypeError("destination_obj must be a dict of column data")
    # if len(destination_obj) == 0:
    #     raise ValueError("destination_obj dict is empty")

    # cdef Py_ssize_t ncols = len(destination_obj)
    # cdef Py_ssize_t expected_rows = -1

    # # Arrays holding final Arrow objects / metadata in input order
    # cdef vector[shared_ptr[Array]]  arrow_columns
    # cdef vector[shared_ptr[Field]]  arrow_fields

    # cdef size_type key_index = -1

    # # Buffers to keep NumPy memory alive until end
    # cdef Py_buffer* np_views = <Py_buffer*>malloc(sizeof(Py_buffer) * ncols)
    # cdef Py_ssize_t view_count = 0

    # # ------------------------------------------------------------------
    # # Iterate through dict items in insertion order
    # # ------------------------------------------------------------------

    # cdef string cname
    # cdef Py_buffer view
    # cdef Int64Builder ibld
    # cdef StringBuilder sbld
    # cdef shared_ptr[Array] arr_cpp
    # for name_py, col in destination_obj.items():
    #     cname = name_py.encode('UTF-8')

       
    #     if PyObject_GetBuffer(col, &view,
    #                             PyBUF_CONTIG_RO | PyBUF_FORMAT) != 0:
    #         raise TypeError(f"Column '{name_py}' must support buffer protocol")
    #     if view.ndim != 1:
    #         PyBuffer_Release(&view)
    #         raise ValueError(f"Column '{name_py}' must be 1-D")

    #     if expected_rows == -1:
    #         expected_rows = view.shape[0]
    #     elif view.shape[0] != expected_rows:
    #         PyBuffer_Release(&view)
    #         raise ValueError("All columns must have equal length")
    #     if view.format in (b"q", b"l"):
    #         # ---------------- int64 -----------------------------
    #         ibld.AppendValues(<int64_t*>view.buf, expected_rows)
    #         ibld.Finish(&arr_cpp)
    #         arrow_columns.push_back(arr_cpp)
    #         arrow_fields.push_back(field(cname, int64()))
    #     elif view.format in (b"10w"):
    #         # ---------------- string -----------------------------
    #         sbld.AppendValues(
    #             <const char**>view.buf,
    #             expected_rows
    #         )
    #         sbld.Finish(&arr_cpp)
    #         arrow_columns.push_back(arr_cpp)
    #         arrow_fields.push_back(field(cname, utf8()))
    #     else:
    #         PyBuffer_Release(&view)
    #         raise TypeError(f"Unsupported NumPy dtype for column '{name_py}'")

    #     # memcpy(&np_views[view_count], &view, sizeof(Py_buffer))
    #     np_views[view_count] = view
    #     view_count += 1

    #     # Detect key column index
    #     if key_index == -1 and cname == b"key":
    #         key_index = arrow_columns.size() - 1

    # if key_index == -1:
    #     raise ValueError("'key' column not found in destination_obj")

    # # ------------------------------------------------------------------
    # # 2. Build Arrow table & export to C stream (still under GIL) --------
    # # ------------------------------------------------------------------

    # cdef shared_ptr[Schema] dest_schema = schema(arrow_fields)
    # cdef shared_ptr[Table]  dest_tbl_cpp = Table.Make(dest_schema, arrow_columns)

    # # Allocate stream and export ------------------------------------------------
    # cdef ArrowArrayStream* dest_stream = <ArrowArrayStream*>malloc(sizeof(ArrowArrayStream))
    # if dest_stream == NULL:
    #     raise MemoryError()



    # cdef shared_ptr[TableBatchReader] t_reader = \
    #         make_shared[TableBatchReader](dest_tbl_cpp)


    # cdef shared_ptr[RecordBatchReader] reader = \
    #         static_pointer_cast[RecordBatchReader, TableBatchReader](t_reader)

    # ExportRecordBatchReader(reader, dest_stream)

    # # ------------------------------------------------------------------
    # # 3. Merge in libcudf (nogil) ---------------------------------------
    # # ------------------------------------------------------------------
    # cdef unique_ptr[arrow_table] dest_bridge
    # cdef vector[table_view] tables_vector
    # cdef vector[size_type] key_cols
    # cdef vector[order] column_order
    # cdef vector[null_order] null_precedence
    # cdef unique_ptr[arrow_table] dest_table

    # with nogil:
    #     dest_table = make_unique[arrow_table](move(dereference(dest_stream)))
        
    #     tables_vector = vector[table_view]()
    #     tables_vector.push_back(source_table.view())
    #     tables_vector.push_back(dest_table.get().view())

    #     key_cols = vector[size_type]()
    #     key_cols.push_back(0)

    #     column_order = vector[order]()
    #     column_order.push_back(order.ASCENDING)

    #     null_precedence = vector[null_order]()
    #     null_precedence.push_back(null_order.AFTER)

    #     merge(
    #         tables_vector,
    #         key_cols,
    #         column_order,
    #         null_precedence
    #     )

    # # ------------------------------------------------------------------
    # # 4. Cleanup --------------------------------------------------------
    # # ------------------------------------------------------------------

    # for i in range(view_count):
    #     PyBuffer_Release(&np_views[i])
    # free(np_views)
    # free(dest_stream)