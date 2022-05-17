const std = @import("std");
const Allocator = std.mem.Allocator;

const Object = struct {
    pub const Data = union(enum) {
        int: i32,
        pair: Pair,
    };
    const Pair = struct {
        head: ?*Object = null,
        tail: ?*Object = null,
    };
    pub const Type = std.meta.Tag(Data);

    data: Data,
    marked: bool,
    next: ?*Object,
};

const stack_max = 256;

const VM = struct {
    stack: [stack_max]*Object,
    stack_size: i32,
    first_object: ?*Object,
};

pub fn newVM(allocator: Allocator) !*VM {
    var ptr = try allocator.create(VM);
    ptr.stack_size = 0;
    ptr.first_object = null;
    return ptr;
}

pub fn push(vm: *VM, value: *Object) void {
    std.debug.assert(vm.stack_size < stack_max);
    vm.stack[@intCast(usize, vm.stack_size)] = value;
    vm.stack_size += 1;
}

pub fn pop(vm: *VM) *Object {
    std.debug.assert(vm.stack_size > 0);
    vm.stack_size -= 1;
    return vm.stack[@intCast(usize, vm.stack_size)];
}

pub fn newObject(allocator: Allocator, vm: *VM, object_type: Object.Type) !*Object {
    var object = try allocator.create(Object);
    object.* = .{
        .data = switch (object_type) {
            .int => .{ .int = 0 },
            .pair => .{ .pair = .{} },
        },
        .marked = false,
        .next = vm.first_object,
    };
    vm.first_object = object;
    return object;
}

pub fn pushInt(allocator: Allocator, vm: *VM, intValue: i32) !void {
    const object = try newObject(allocator, vm, .int);
    object.data.int = intValue;
    push(vm, object);
}

pub fn pushPair(allocator: Allocator, vm: *VM) !*Object {
    const object = try newObject(allocator, vm, .pair);
    object.data.pair.tail = pop(vm);
    object.data.pair.head = pop(vm);
    push(vm, object);
    return object;
}

pub fn markAll(vm: *VM) void {
    var index: usize = 0;
    while (index < vm.stack_size) : (index += 1) {
        mark(vm.stack[index]);
    }
}

pub fn mark(object: *Object) void {
    // If already marked, we're done. Check this first
    // to avoid recursing on cycles in the object graph.
    if (object.marked) return;

    object.marked = true;

    if (object.data == .pair) {
        if (object.data.pair.head) |head| {
            mark(head);
        }
        if (object.data.pair.tail) |tail| {
            mark(tail);
        }
    }
}

pub fn sweep(allocator: Allocator, vm: *VM) void {
    var object = &vm.first_object;
    while (object.* != null) {
        if (!object.*.?.marked) {
            const unreached = object.*.?;
            object.* = unreached.next;
            allocator.destroy(unreached);
        } else {
            object.*.?.marked = false;
            object = &object.*.?.next;
        }
    }
}

pub fn gc(allocator: Allocator, vm: *VM) void {
    _ = allocator;
    markAll(vm);
    sweep(allocator, vm);
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const vm = try newVM(allocator);
    defer allocator.destroy(vm);

    defer gc(allocator, vm);

    try pushInt(allocator, vm, 1);
    try pushInt(allocator, vm, 2);
    const a = pop(vm);
    const b = pop(vm);

    try pushInt(allocator, vm, 3);
    try pushInt(allocator, vm, 4);
    const c = try pushPair(allocator, vm);

    const d = pop(vm);

    _ = a;
    _ = b;
    _ = c;
    _ = d;
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
