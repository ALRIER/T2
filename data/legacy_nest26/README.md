# Legacy NEST26 archive reference

The historical expanded-basis validation is available from Zenodo record
`10.5281/zenodo.21046199`.

T2 does not vendor the approximately 939 MB raw archive into Git. The archive
contains fixed-weight validation outputs and task-level error tables, not canonical
26-column component matrices suitable for replacing T2 training. It may be used for
historical regression checks, frozen-model comparisons, and provenance audits.

Downloaded source files must be verified against the Zenodo manifest before local
use. They must never be silently used as T2 training or held-out observations.
