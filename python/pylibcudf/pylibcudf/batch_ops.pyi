from pylibcudf.table import Table

from pylibcudf.copying import OutOfBoundsPolicy

def multiget(
    source_table: Table,
    column_idx: int,
    keys: object,
    bounds_policy: OutOfBoundsPolicy
) -> Table: ...
def multiset(
    source_table: Table,
    keys_obj: object,
    destination_obj: object,
) -> Table: ...