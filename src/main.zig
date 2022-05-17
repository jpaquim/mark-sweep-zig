const std = @import("std");
const Allocator = std.mem.Allocator;

const Object = struct {
    const Data = union(enum) {
        int: i32,
        pair: Pair,
    };
    const Pair = struct {
        head: ?*Object = null,
        tail: ?*Object = null,
    };

    data: Data,
    marked: bool,
    next: ?*Object,

    pub fn init(vm: *VM, object_type: std.meta.Tag(Data)) !*Object {
        if (vm.num_objects == vm.max_objects) vm.gc();

        var object = try vm.allocator.create(Object);
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

    const Self = @This();

    pub fn mark(self: *Self) void {
        // If already marked, we're done. Check this first
        // to avoid recursing on cycles in the object graph.
        if (self.marked) return;

        self.marked = true;

        if (self.data == .pair) {
            if (self.data.pair.head) |head| {
                head.mark();
            }
            if (self.data.pair.tail) |tail| {
                tail.mark();
            }
        }
    }
};

const stack_max = 256;
const init_obj_num_max = 8;

const VM = struct {
    allocator: Allocator,
    stack: [stack_max]*Object,
    stack_size: i32,
    first_object: ?*Object,
    num_objects: i32,
    max_objects: i32,

    pub fn init(allocator: Allocator) !*VM {
        var vm = try allocator.create(VM);
        vm.allocator = allocator;
        vm.stack_size = 0;
        vm.first_object = null;
        vm.num_objects = 0;
        vm.max_objects = init_obj_num_max;
        return vm;
    }

    const Self = @This();

    pub fn push(self: *Self, value: *Object) void {
        std.debug.assert(self.stack_size < stack_max);
        self.stack[@intCast(usize, self.stack_size)] = value;
        self.stack_size += 1;
    }

    pub fn pop(self: *Self) *Object {
        std.debug.assert(self.stack_size > 0);
        self.stack_size -= 1;
        return self.stack[@intCast(usize, self.stack_size)];
    }

    pub fn pushInt(self: *Self, intValue: i32) !void {
        const object = try Object.init(self, .int);
        object.data.int = intValue;
        self.push(object);
    }

    pub fn pushPair(self: *Self) !*Object {
        const object = try Object.init(self, .pair);
        object.data.pair.tail = self.pop();
        object.data.pair.head = self.pop();
        self.push(object);
        return object;
    }

    pub fn markAll(self: *Self) void {
        var index: usize = 0;
        while (index < self.stack_size) : (index += 1) {
            self.stack[index].mark();
        }
    }

    pub fn sweep(self: *Self) void {
        var object_ptr = &self.first_object;
        while (object_ptr.*) |object| {
            if (!object.marked) {
                object_ptr.* = object.next;
                self.allocator.destroy(object);
                self.num_objects -= 1;
            } else {
                object.marked = false;
                object_ptr = &object.next;
            }
        }
    }

    pub fn gc(self: *Self) void {
        const num_objects = self.num_objects;

        self.markAll();
        self.sweep();

        self.max_objects = self.num_objects * 2;

        std.debug.print("Collected {} objects, {} remaining\n", .{ num_objects - self.num_objects, self.num_objects });
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const vm = try VM.init(allocator);
    defer allocator.destroy(vm);

    defer vm.gc();

    try vm.pushInt(1);
    try vm.pushInt(2);
    const a = vm.pop();
    const b = vm.pop();
    std.debug.print("{}\n", .{a});
    std.debug.print("{}\n", .{b});

    try vm.pushInt(3);
    try vm.pushInt(4);
    _ = try vm.pushPair();
    const c = vm.pop();
    std.debug.print("{}\n", .{c});

    try vm.pushInt(5);
    try vm.pushInt(6);
    _ = try vm.pushPair();
    const d = vm.pop();
    std.debug.print("{}\n", .{d});

    try vm.pushInt(7);
    try vm.pushInt(8);
    _ = try vm.pushPair();
    const e = vm.pop();
    std.debug.print("{}\n", .{e});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
