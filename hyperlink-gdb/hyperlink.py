import gdb
import struct
import itertools

PTR_SIZE = 8
SEARCH_RANGE = 0x1800

def unpack_ptr(barray):
    return struct.unpack("<Q", barray)[0]
    
def is_kernel_pointer(val):
    return val & 0xffff000000000000 == 0xffff000000000000

def read(addr, size):
    return gdb.selected_inferior().read_memory(addr, size)

def is_circular_list_ptr(addr, filter_func=None):
    visited_ptrs = set()
    length = 0
    while True:
        visited_ptrs.add(addr)
        try:
            if filter_func:
                if not filter_func(addr):
                    return (False, length)
            addr = unpack_ptr(read(addr, PTR_SIZE))
        except gdb.error:
            return (False, length)
        if addr in visited_ptrs:
            return (True, length)
        length += 1

def traverse_list(addr):
    visited_ptrs = set()
    while True:
        visited_ptrs.add(addr)
        yield addr
        addr = unpack_ptr(read(addr, PTR_SIZE))
        if addr in visited_ptrs:
            return

def check_comm_at_offset(addr, offset):
    addr = addr+offset
    if not 0 < addr < 2**64-1 or not is_kernel_pointer(addr):
        return False
    comm = bytes(read(addr, 16))
    comm = bytes(itertools.takewhile(lambda x: x != 0, comm))
    return comm.isascii() and len(comm) > 0

def guess_tasks_offset():
    pass

class ListProcesses(gdb.Command):
    def __init__(self):
        super().__init__("hyperlink-ps", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        start_addr = int(arg, 0)
        print(f"Looking for kernel pointers around 0x{start_addr:x}")
        content = read(start_addr-SEARCH_RANGE, 2*SEARCH_RANGE)
        circular_lists = []
        for i in range(0, len(content), PTR_SIZE):
            offset = i - SEARCH_RANGE
            val = unpack_ptr(content[i:i+PTR_SIZE])
            if is_kernel_pointer(val):
                try:
                    deref = read(val, PTR_SIZE)
                    deref = unpack_ptr(deref)
                    deref = f"{deref:x}"
                except gdb.error:
                    deref = "<invalid addr>"

                output = f"{offset:04x} 0x{start_addr+offset:x}: {val:x} -> {deref}"
                
                # Check for a simple circular list without further constraints
                output_additions = []
                is_circular_list, length = is_circular_list_ptr(val)
                if is_circular_list:
                    output_additions.append(f"circular len={length}")

                # Check for a circular list with constant comm offset
                is_circular_list, length = is_circular_list_ptr(val, lambda addr: check_comm_at_offset(addr, -offset))
                if is_circular_list:
                    output_additions.append(f"comm const")
                    circular_lists.append((length, offset))

                if len(output_additions) > 0:
                    output += " [" + ", ".join(output_additions) + "]"

                print(output)

        # Take the longest circular list as the candidate for the task list
        offset_tasks_list = max(circular_lists, key=lambda x: x[0])[1]
        print(f"Guessed offset of task_struct->tasks.next: {hex(offset_tasks_list)}")

        # Search for the PID with the method described in the Trustzone Rootkit paper
        # Assume that the PID is 4 byte aligned
        assert(start_addr % 4 == 0)
        for candidate_offset in range(-SEARCH_RANGE, SEARCH_RANGE, 4):
            prev_pid = 0
            found = False
            for e in itertools.islice(traverse_list(start_addr+offset_tasks_list), 1, 6):
                pid_candidate = struct.unpack("<I", read(e+candidate_offset, 4))[0]
                if (prev_pid == 0 and pid_candidate == 0x1) or (prev_pid > 0 and prev_pid < pid_candidate):
                    found = True
                    prev_pid = pid_candidate
                else:
                    found = False
                    break
            if found:
                pid_offset = candidate_offset
                print(f"Guessed PID offset: {hex(candidate_offset)}")
                break

        print("\n=== Process List ===")
        visited_ptrs = set()
        addr = start_addr+offset_tasks_list
        for addr in traverse_list(addr):
            comm = bytes(read(addr-offset_tasks_list, 16))
            comm = bytes(itertools.takewhile(lambda x: x != 0, comm))
            pid = struct.unpack("<I", read(addr+pid_offset, 4))[0]
            print(f"0x{addr:016x} PID: {pid}, Comm: {comm.decode()}")

ListProcesses()
