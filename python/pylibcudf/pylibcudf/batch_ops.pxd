from pylibcudf.libcudf.copying cimport (
    out_of_bounds_policy,
)

from .table cimport Table as cudf_Table


cpdef cudf_Table multiget(
    cudf_Table source_table,
    object keys,
    out_of_bounds_policy bounds_policy
)

cpdef cudf_Table multiset(
    cudf_Table source_table,
    object keys_obj,
    object destination_obj,
)