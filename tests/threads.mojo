"""Joinable POSIX threads for standalone concurrency tests on Linux/macOS.

Each job owns its output. Slots stay at fixed addresses until every worker
has joined, and worker exceptions are re-raised on the calling thread.
"""
from std.ffi import external_call
from std.memory import Pointer


trait Job(Deinitable, Movable):
    def run(mut self) raises:
        ...


struct _Slot[J: Job](Movable):
    var job: Self.J
    var failed: Bool
    var message: String

    def __init__(out self, var job: Self.J):
        self.job = job^
        self.failed = False
        self.message = ""

    def run(mut self):
        try:
            self.job.run()
        except e:
            self.failed = True
            self.message = String(e)

    def into_job(deinit self) -> Self.J:
        return self.job^


def _entry[J: Job](address: Int) abi("C") -> Int:
    Pointer[_Slot[J], MutAnyOrigin](unsafe_from_address=address)[].run()
    return 0


def run_jobs[J: Job](mut jobs: List[J]) raises:
    if not jobs:
        return
    var slots = List[_Slot[J]](capacity=len(jobs))
    while jobs:
        slots.append(_Slot[J](jobs.pop(0)))
    var entry: def(Int) thin abi("C") -> Int = _entry[J]
    var entry_address = Pointer(to=entry).unsafe_bitcast[Int]()[]
    var threads = List[UInt64](length=len(slots) - 1, fill=0)
    var started = 0
    var spawn_error = String()
    for t in range(len(threads)):
        var rc = external_call["pthread_create", Int32](
            Int(Pointer(to=threads[t])),
            0,
            entry_address,
            Int(Pointer(to=slots[t])),
        )
        if rc != 0:
            spawn_error = "pthread_create failed with code " + String(rc)
            break
        started += 1
    for t in range(started, len(slots)):
        slots[t].run()
    for t in range(started):
        _ = external_call["pthread_join", Int32](threads[t], 0)
    if spawn_error:
        raise Error(spawn_error)
    for t in range(len(slots)):
        if slots[t].failed:
            raise Error(slots[t].message)
    while slots:
        jobs.append(slots.pop(0).into_job())
