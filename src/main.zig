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
};

const stack_max = 256;

const VM = struct {
    stack: [stack_max]*Object,
    stack_size: i32,
};

pub fn newVM(allocator: Allocator) !*VM {
    var ptr = try allocator.create(VM);
    ptr.stack_size = 0;
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
    _ = vm;
    var ptr = try allocator.create(Object);
    ptr.* = .{
        .data = switch (object_type) {
            .int => .{ .int = 0 },
            .pair => .{ .pair = .{} },
        },
        .marked = false,
    };
    return ptr;
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
    for (vm.stack) |ptr| {
        mark(ptr);
    }
}

pub fn mark(object: *Object) void {
    // If already marked, we're done. Check this first
    // to avoid recursing on cycles in the object graph.
    if (object.marked) return;

    object.marked = true;

    if (object.data == .pair) {
        mark(object.data.head);
        mark(object.data.tail);
    }
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const vm = try newVM(allocator);
    defer allocator.destroy(vm);

    try pushInt(allocator, vm, 1);
    try pushInt(allocator, vm, 2);
    const a = pop(vm);
    const b = pop(vm);
    defer {
        allocator.destroy(a);
        allocator.destroy(b);
    }
    std.debug.print("a: {}\n", .{a});
    std.debug.print("b: {}\n", .{b});

    try pushInt(allocator, vm, 3);
    try pushInt(allocator, vm, 4);
    const c = try pushPair(allocator, vm);
    defer {
        allocator.destroy(c.data.pair.head.?);
        allocator.destroy(c.data.pair.tail.?);
        allocator.destroy(c);
    }
    std.debug.print("c: {}\n", .{c});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
