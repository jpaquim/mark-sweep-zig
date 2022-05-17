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
const init_obj_num_max = 8;

const VM = struct {
    stack: [stack_max]*Object,
    stack_size: i32,
    first_object: ?*Object,
    num_objects: i32,
    max_objects: i32,
};

pub fn newVM(allocator: Allocator) !*VM {
    var vm = try allocator.create(VM);
    vm.stack_size = 0;
    vm.first_object = null;
    vm.num_objects = 0;
    vm.max_objects = init_obj_num_max;
    return vm;
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
    if (vm.num_objects == vm.max_objects) gc(allocator, vm);

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
    vm.num_objects += 1;
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
    var object_ptr = &vm.first_object;
    while (object_ptr.*) |object| {
        if (!object.marked) {
            object_ptr.* = object.next;
            allocator.destroy(object);
            vm.num_objects -= 1;
        } else {
            object.marked = false;
            object_ptr = &object.next;
        }
    }
}

pub fn gc(allocator: Allocator, vm: *VM) void {
    const num_objects = vm.num_objects;

    markAll(vm);
    sweep(allocator, vm);

    vm.max_objects = vm.num_objects * 2;

    std.debug.print("Collected {} objects, {} remaining\n", .{ num_objects - vm.num_objects, vm.num_objects });
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
    std.debug.print("{}\n", .{a});
    std.debug.print("{}\n", .{b});

    try pushInt(allocator, vm, 3);
    try pushInt(allocator, vm, 4);
    _ = try pushPair(allocator, vm);
    const c = pop(vm);
    std.debug.print("{}\n", .{c});

    try pushInt(allocator, vm, 5);
    try pushInt(allocator, vm, 6);
    _ = try pushPair(allocator, vm);
    const d = pop(vm);
    std.debug.print("{}\n", .{d});

    try pushInt(allocator, vm, 7);
    try pushInt(allocator, vm, 8);
    _ = try pushPair(allocator, vm);
    const e = pop(vm);
    std.debug.print("{}\n", .{e});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
