const std = @import("std");
const bufferedReader = @import("std").io.bufferedReader;
const Reader = @import("std").io.AnyReader;
const BigEndian = @import("std").builtin.Endian.big;
const mem = @import("std").mem;
const kls = @import("class_file.zig");
const codef = @import("code.zig");

const allocator = std.heap.page_allocator;
const bufPrint = std.fmt.bufPrint;

const code_info = codef.code_info;

const ClassFile = kls.ClassFile;
const interfaces = kls.interfaces;
const method_info = kls.method_info;
const attribute_info = kls.attribute_info;
const cp_info = kls.cp_info;
const ConstantPoolTags = kls.ConstantPoolTags;

const ClassAccessFlags = kls.ClassAccessFlags;
const MethodAccessFlags = kls.MethodAccessFlags;

const t_u4 = kls.t_u4;
const t_u2 = kls.t_u2;
const t_u1 = kls.t_u1;

fn parseFlags(value: u16, flags: []const []const u8, values: []const u16) ![]const []const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    for (flags, values) |flag, val| {
        if ((value & val) != 0) {
            try list.append(flag);
        }
    }
    return list.toOwnedSlice();
}

pub fn main() !void {
    const file = "Main.class";
    const filePointer = try std.fs.cwd().openFile(file, .{ .mode = .read_only });
    defer filePointer.close();

    var BuffReader = bufferedReader(filePointer.reader());
    var reader = BuffReader.reader().any();

    var conf: ClassFile = .{
        .magic = try reader.readInt(t_u4, BigEndian),
        .minor_version = try reader.readInt(t_u2, BigEndian),
        .major_version = try reader.readInt(t_u2, BigEndian),
        .constant_pool_count = try reader.readInt(t_u2, BigEndian),
        .constant_pool = undefined,
        .access_flags = undefined,
        .this_class = 0,
        .super_class = 0,
        .interfaces = undefined,
        .methods = undefined,
        .attributes = undefined,
    };

    std.debug.print("Magic: {x}\n", .{conf.magic});

    conf.constant_pool = try allocator.alloc(cp_info, conf.constant_pool_count);

    var index: u16 = 0;
    while (index < conf.constant_pool_count - 1) : (index += 1) {
        const tag: u8 = try reader.readInt(u8, BigEndian);
        const convertedTag = ConstantPoolTags.fromInt(tag) catch {
            std.debug.panic("Unexpected tag: {d}", .{tag});
        };
        var cpInfo: cp_info = undefined;
        cpInfo.tag = convertedTag;
        if (convertedTag == ConstantPoolTags.CONSTANT_Methodref) {
            cpInfo.class_index = try reader.readInt(u16, BigEndian);
            cpInfo.name_and_type_index = try reader.readInt(u16, BigEndian);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Class) {
            cpInfo.name_index = try reader.readInt(u16, BigEndian);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_NameAndType) {
            cpInfo.name_index = try reader.readInt(u16, BigEndian);
            cpInfo.descriptor_index = try reader.readInt(u16, BigEndian);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Utf8) {
            const length = try reader.readInt(u16, BigEndian);
            cpInfo.bytes = try allocator.alloc(u8, length);
            _ = try reader.read(cpInfo.bytes);
            cpInfo.bytes_length = length;
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Fieldref) {
            cpInfo.class_index = try reader.readInt(u16, BigEndian);
            cpInfo.name_and_type_index = try reader.readInt(u16, BigEndian);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_String) {
            cpInfo.string_index = try reader.readInt(u16, BigEndian);
        } else {
            std.debug.panic("Unexpected tag: {any}", .{convertedTag});
        }

        conf.constant_pool[index] = cpInfo;
    }

    const access_flags = try reader.readInt(u16, BigEndian);
    conf.access_flags = try parseFlags(access_flags, &ClassAccessFlags.flags, &ClassAccessFlags.values);
    conf.this_class = try reader.readInt(u16, BigEndian);
    conf.super_class = try reader.readInt(u16, BigEndian);

    const interfacesCount = try reader.readInt(u16, BigEndian);
    var loop: u16 = 0;
    while (loop < interfacesCount) : (loop += 1) {
        @panic("We do not support interfaces yet...");
    }

    const fieldsCount = try reader.readInt(t_u2, BigEndian);
    loop = 0;
    while (loop < fieldsCount) : (loop += 1) {
        @panic("We do not support fields yet...");
    }

    const methodsCount = try reader.readInt(t_u2, BigEndian);

    conf.methods = try parse_methods(reader, methodsCount);

    const attCount = try reader.readInt(t_u2, BigEndian);
    conf.attributes = try parse_attributes(reader, attCount);

    // loop = 0;
    // for (conf.constant_pool) |cp| {
    //     if (cp.tag == ConstantPoolTags.CONSTANT_Utf8) {
    //         std.debug.print("Bytes@{d}: {s}\n", .{ loop, cp.bytes[0..cp.bytes.len] });
    //     }
    //     loop += 1;
    // }

    const method: method_info = try find_method_name(conf, "main");
    const code: attribute_info = try find_attribute_by_name(conf, method.attributes, "Code");
    const codeInfo: code_info = try parse_code_info(code.info);
    execute(conf, codeInfo.code) catch {};
}

pub fn find_method_name(conf: ClassFile, name: []const u8) !method_info {
    var loop: t_u1 = 0;
    while (loop < conf.methods.len) : (loop += 1) {
        const bytes = conf.constant_pool[conf.methods[loop].name_index - 1].bytes;
        if (mem.eql(u8, bytes, name)) {
            return conf.methods[loop];
        }
    }
    return undefined;
}

pub fn find_attribute_by_name(conf: ClassFile, attributes: []attribute_info, name: []const u8) !attribute_info {
    var loop: t_u1 = 0;
    while (loop < attributes.len) : (loop += 1) {
        const bytes = conf.constant_pool[attributes[loop].attribute_name_index - 1].bytes;
        if (mem.eql(u8, bytes, name)) {
            return attributes[loop];
        }
    }
    return undefined;
}

pub fn parse_methods(reader: anytype, methods_count: t_u2) ![]method_info {
    var loop: t_u2 = 0;
    var ret = try allocator.alloc(method_info, methods_count);
    while (loop < methods_count) : (loop += 1) {
        var meth: method_info = undefined;
        meth.access_flags = try parseFlags(try reader.readInt(t_u2, BigEndian), &MethodAccessFlags.flags, &MethodAccessFlags.values);
        meth.name_index = try reader.readInt(t_u2, BigEndian);
        meth.descriptor_index = try reader.readInt(t_u2, BigEndian);
        meth.attributes_count = try reader.readInt(t_u2, BigEndian);
        meth.attributes = try parse_attributes(reader, meth.attributes_count);
        ret[loop] = meth;
    }
    return ret;
}

pub fn parse_attributes(reader: anytype, attribute_count: t_u2) ![]attribute_info {
    var loop: t_u2 = 0;
    var ret = try allocator.alloc(attribute_info, attribute_count);
    while (loop < attribute_count) : (loop += 1) {
        var att: attribute_info = .{
            .attribute_name_index = try reader.readInt(t_u2, BigEndian),
            .attribute_length = try reader.readInt(t_u4, BigEndian),
            .info = undefined,
        };
        att.info = try allocator.alloc(t_u1, att.attribute_length);
        _ = try reader.read(att.info);
        ret[loop] = att;
    }
    return ret;
}

pub fn parse_code_info(info: []u8) !code_info {
    var f = std.io.fixedBufferStream(info);
    var reader = f.reader().any();

    var code: code_info = undefined;

    code.max_stack = try reader.readInt(t_u2, BigEndian);
    code.max_locals = try reader.readInt(t_u2, BigEndian);
    code.code_length = try reader.readInt(t_u4, BigEndian);
    code.code = try allocator.alloc(t_u1, code.code_length);
    _ = try reader.read(code.code);

    return code;
}

pub fn get_name_of_class(conf: ClassFile, index: t_u2) ![]const u8 {
    const bytes = conf.constant_pool[conf.constant_pool[index - 1].name_index - 1].bytes;
    return bytes[0..bytes.len];
}

pub fn get_name_of_member(conf: ClassFile, index: t_u2) ![]const u8 {
    const bytes = conf.constant_pool[conf.constant_pool[index - 1].name_index - 1].bytes;
    return bytes[0..bytes.len];
}

const GETSTATIC_OPCODE = 0xb2;
const LDC_OPCODE = 0x12;
const INVOKEVIRTUAL_OPCODE = 0xb6;
const RETURN_OPCODE = 0xb1;
const BIPUSH_OPCODE = 0x10;

pub const stack_struct = struct {
    type: []const u8,
    constant: cp_info,
    value: u8,
};

pub fn execute(conf: ClassFile, code: []u8) !void {
    std.debug.print("Executing code...\n", .{});
    var f = std.io.fixedBufferStream(code);
    var reader = f.reader().any();

    var stack = std.ArrayList(stack_struct).init(allocator);

    while (true) {
        const opcode = try reader.readInt(t_u1, BigEndian);
        switch (opcode) {
            GETSTATIC_OPCODE => {
                const index = try reader.readInt(t_u2, BigEndian);
                const fieldref = conf.constant_pool[index - 1];
                const name_of_class = try get_name_of_class(conf, fieldref.class_index);
                const name_of_member = try get_name_of_member(conf, fieldref.name_and_type_index);
                if (mem.eql(u8, name_of_class, "java/lang/System") and mem.eql(u8, name_of_member, "out")) {
                    try stack.append(.{ .type = "FakePrintStream", .constant = undefined, .value = 0 });
                } else {
                    std.debug.panic("Unexpected class: {s}/{s}", .{ name_of_class, name_of_member });
                }
            },
            LDC_OPCODE => {
                const index = try reader.readInt(t_u1, BigEndian);
                const cp = conf.constant_pool[index - 1];
                try stack.append(.{ .type = "Constant", .constant = cp, .value = 0 });
            },
            INVOKEVIRTUAL_OPCODE => {
                const index = try reader.readInt(t_u2, BigEndian);
                const methodref = conf.constant_pool[index - 1];
                const name_of_class = try get_name_of_class(conf, methodref.class_index);
                const name_of_member = try get_name_of_member(conf, methodref.name_and_type_index);
                if (mem.eql(u8, name_of_class, "java/io/PrintStream") and mem.eql(u8, name_of_member, "println")) {
                    const len = stack.items.len;
                    if (len < 2) {
                        std.debug.panic("Stack underflow: {d}", .{len});
                    }

                    const obj: stack_struct = stack.items[len - 2];
                    if (!mem.eql(u8, obj.type, "FakePrintString")) {
                        // std.debug.panic("Unsupported stream type: {any}", obj.type[0..obj.type.len]);
                    }

                    const arg: stack_struct = stack.items[len - 1];
                    if (mem.eql(u8, arg.type, "Constant")) {
                        const bytes = conf.constant_pool[arg.constant.string_index - 1].bytes;
                        std.debug.print("{s}\n", .{bytes[0..bytes.len]});
                    } else if (mem.eql(u8, arg.type, "Integer")) {
                        std.debug.print("{d}\n", .{arg.value});
                    } else {
                        std.debug.panic("Unsupported argument type: {s}", .{arg.type[0..arg.type.len]});
                    }
                } else {
                    std.debug.panic("Unexpected class: {s}/{s}", .{ name_of_class, name_of_member });
                }
            },
            RETURN_OPCODE => {
                return;
            },
            BIPUSH_OPCODE => {
                const byte = try reader.readInt(t_u1, BigEndian);
                try stack.append(.{ .type = "Integer", .constant = undefined, .value = byte });
            },
            else => {
                std.debug.panic("Unexpected opcode: {x}", .{opcode});
            },
        }
    }
}
